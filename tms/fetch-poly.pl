#!/usr/local/bin/perl -w

BEGIN {
	push @INC, '.';
}
use strict;

use WWW::Curl::Easy;
use WWW::Curl::Multi;
use Math::Polygon;
use Fcntl qw/:DEFAULT/;
use File::Path qw/make_path/;

use WebMaps qw/:standard/;

use constant	MAXQUEUE	=> 100;

my @poly;
my @NoData;
my @InPoly;	# 1 - in poly, 2 - out of poly

sub 
usage() {
	die("Usage: $0 provider cachedir levels polyfile\n");
};

usage() if ($#ARGV != 3);
usage() unless ($ARGV[2] =~ /(\d+)-(\d+)/);

my ($minzoom, $maxzoom) = ($1, $2);

usage() if ($minzoom > $maxzoom);

open(my $fh, '<', $ARGV[3]) or die $!;

while (<$fh>) {
	next unless (/^   /);

	my ($lon, $lat) = split;
	chomp($lat);

	push(@poly, {lat => $lat + 0, lon => $lon + 0});
}
close($fh);

die("Bad poly\n") if ($#poly < 2);

ProjInit($ARGV[0]);

my $cachedir = $ARGV[1];

die("Can't write to $cachedir\n")
	unless (-d $cachedir && -w $cachedir);

## START

my $multi = WWW::Curl::Multi->new;
my %easy;
my ($fetched, $errors, $washere, $outofpoly, $nodata, $todo, $retries, $start);
my $sigflag = 0;

sub
info() {
	my $done = ($fetched + $errors + $nodata + $washere + $outofpoly);
	my $time = (time() - $start);

	return if ($time == 0 || $todo == 0);

	printf("%u of %u tiles (%2.2f%%) done\n" .
	       "fetched %u, errors %u, retries %u, nodata %u, was here %u, out of poly %u\n" .
	       "%.2f fetches per second, %.2f tiles per second\n",
	    $done, $todo, $done/$todo * 100,
	    $fetched, $errors, $retries, $nodata, $washere, $outofpoly,
	    $fetched / $time, $done / $time);

	$sigflag = 0;
}

sub
siginfo() { $sigflag = 1 }

$SIG{'INFO'} = \&siginfo;

sub
process_data($$) {
	my $data = shift;
	my ($z, $x, $y) = unpack('L3', shift);
	my $f;

	make_path("$cachedir/$z/$x");
	sysopen($f, "$cachedir/$z/$x/$y", O_WRONLY|O_CREAT|O_APPEND)
		or warn("sysopen: $!");
	syswrite($f, $data)
		or warn("syswrite: $!");
	close($f);

	return (length($data));
}

sub
process_rv()
{

	while (my ($id, $rv) = $multi->info_read) {
		next unless $id;
		if ($rv != 0) {
			my ($z, $x, $y) = ($id =~ /(\d+):(\d+):(\d+)/);
			my $xfer = $easy{$id};

			printf("Error fetching %u/%u/%u: %u %s %s\n",
			    $z, $x, $y, $rv, $xfer->strerror($rv),
			    $xfer->errbuf);
			$errors++;
		} else {
			$fetched++;
		}
		delete $easy{$id};
	}
}

sub
fetch($$$)
{
	my ($z, $x, $y) = @_;
	my $id = pack('L3', $z, $x, $y);
#   CURLOPT_PRIVATE
#       Despite what the libcurl manual says, in Perl land, only string values
#       are suitable for this option.
	my $sid = sprintf("%u:%u:%u", $z, $x, $y);

	my $xfer = WWW::Curl::Easy->new;
	my $url = $WebMaps::Service->{UrlGen}($x, $y, $z);
	$xfer->setopt(CURLOPT_URL, $url);
	$xfer->setopt(CURLOPT_PRIVATE, $sid);
	$xfer->setopt(CURLOPT_USERAGENT, UA);
	$xfer->setopt(CURLOPT_WRITEFUNCTION, \&process_data);
	$xfer->setopt(CURLOPT_WRITEDATA, $id);
	$easy{$sid} = $xfer;
	$multi->add_handle($xfer);
}

for (my $z = $minzoom; $z <= $maxzoom; $z++) {
	my @points;
	my $zdone;

	for (my $i = 0; $i <= $#poly; $i++) {
		my ($x, $y) = $WebMaps::Service->{Proj}($poly[$i]->{lon}, $poly[$i]->{lat}, $z);
		push(@points, [$x, $y]);
	}

	my $Poly = Math::Polygon->new(@points);

	my ($minx, $miny, $maxx, $maxy) = $Poly->bbox();

	my ($bminx, $bminy, $bmaxx, $bmaxy) = (TileNum($minx), TileNum($miny),
	    TileNum($maxx), TileNum($maxy));

	make_path("$cachedir/$z");

	$zdone = 1
		if (-r "$cachedir/$z/done");

	($fetched, $errors, $retries, $washere, $outofpoly, $nodata) = (0, 0, 0, 0, 0, 0);
	$start = time();
	$todo = ($bmaxy - $bminy + 1)*($bmaxx - $bminx + 1);

	printf("Zoom %u: %u tiles to do, bbox %u,%u->%u,%u\n",
	    $z, $todo, $bminx, $bminy, $bmaxx, $bmaxy);

TILEX:	for (my $x = $bminx; $x <= $bmaxx; $x++) {
TILEY:	    for (my $y = $bminy; $y <= $bmaxy; $y++) {

		info() if ($sigflag == 1);

		# check InPoly cache
		for (my $xz = $z-1, my $i = 1; $xz >= $minzoom; $xz--, $i++) {
			my $in = $InPoly[$xz][int($x/(2**$i))][int($y/(2**$i))];

			if (defined($in) && $in == 1) {
				goto INPOLY;
			} elsif (defined($in) && $in == 2) {
				$outofpoly++;
				next TILEY;
			}
		}

		my $Rect = Math::Polygon->new(
		    [$x * WebMaps::TileSize, $y * WebMaps::TileSize ],
		    [($x+1) * WebMaps::TileSize, $y * WebMaps::TileSize ],
		    [($x+1) * WebMaps::TileSize, ($y+1) * WebMaps::TileSize ],
		    [$x * WebMaps::TileSize, ($y+1) * WebMaps::TileSize ],
		    [$x * WebMaps::TileSize, $y * WebMaps::TileSize ]);

		my $vertices = 0;
		foreach my $point (($Rect->points)[0,1,2,3]) {
			$vertices++ if ($Poly->contains($point));
		}

		# Cache positive result
		$InPoly[$z][$x][$y] = 1
			if ($vertices == 4 && $z < $maxzoom);
		goto INPOLY
			if ($vertices > 0);

		foreach my $point ($Poly->points()) {
			goto INPOLY
				if ($Rect->contains($point));
		}

		# Cache negative result
		$InPoly[$z][$x][$y] = 2
			if ($z < $maxzoom);
		$outofpoly++;
		next TILEY;

INPOLY:
		if (-r "$cachedir/$z/$x/$y") {
			$washere++;
			next TILEY;
		} elsif (defined($zdone)) {
			$nodata++;
			$NoData[$z][$x][$y] = 1
				if ($z < $maxzoom);
			next TILEY;
		}

		for (my $xz = $z-1, my $i = 1; $xz >= $minzoom; $xz--, $i++) {
			if (defined ($NoData[$xz][int($x/(2**$i))][int($y/(2**$i))])) {
				$nodata++;
				next TILEY;
			}
		}

		fetch($z, $x, $y);

		while ((my $queue = $multi->perform) > MAXQUEUE) {
			if ($queue != keys %easy) {
				process_rv();
			}
		}
	    }
	}

	my $sleeping = 0;
	while ($multi->perform != 0) {
		sleep(1);
		printf("Draining remaining requests:") if ($sleeping++ == 10);
		printf(".") if ($sleeping > 10);
	}
	printf("\n") if ($sleeping >= 10);
	process_rv();

	if ($errors == 0) {
		my $f;
		sysopen($f, "$cachedir/$z/done", O_WRONLY|O_CREAT|O_TRUNC)
	    		or warn("sysopen: $!");
		printf($f "Zoom %u: fetched %u, errors %u, nodata %u, was here %u, out of poly %u\n",
		    $z, $fetched, $errors, $nodata, $washere, $outofpoly);
		close($f);
	}
	printf("Zoom %u finished in %u second(s):\n".
	       "fetched %u, errors %u, retries %u, nodata %u, was here %u, out of poly %u\n",
		$z, time() - $start,
		$fetched, $errors, $retries, $nodata, $washere, $outofpoly);
}
