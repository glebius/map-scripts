#!/usr/local/bin/perl -w

use strict;

use Math::Polygon;
use Fcntl qw/:DEFAULT/;
use File::Path qw/make_path/;

use HTTP::Async;
use HTTP::Request;

use WebMaps qw/:standard/;

use constant	MAXWORK		=> 16;
use constant	MAXQUEUE	=> 100;
use constant	SLOWDOWN_LIM	=> 30;
use constant	TIMEOUT		=> 20;
use constant	UA => 'User-Agent', 'Mozilla/5.0 (X11; FreeBSD amd64; rv:18.0) Gecko/20100101 Firefox/18.0';

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

my $async = HTTP::Async->new( slots => MAXWORK, timeout => TIMEOUT );
my ($fetched, $errors, $washere, $outofpoly, $nodata, $todo, $retries, $start);
my $sigflag = 0;
my $sndqoverflows = 0;

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
	print($async->info);

	$sigflag = 0;
}

sub
siginfo() { $sigflag = 1 }

$SIG{'INFO'} = \&siginfo;

my %URLHash;

sub
process_response($$) {
	my ($res, $id) = @_;
	my $req = $res->request;
	my ($z, $x, $y, $ux, $uy) = (@{$URLHash{$id}})[0,1,2,3,4];

	if ($res->is_success && length($res->content) > 0) {
		if (defined($WebMaps::Service->{ResChk}) &&
		    $WebMaps::Service->{ResChk}($res) != 1) {
			$nodata++;
			$NoData[$z][$x][$y] = 1
				if ($z < $maxzoom);
		}

		my $f;

		make_path("$cachedir/$z/$ux");
		sysopen($f, "$cachedir/$z/$ux/$uy",
		    O_WRONLY|O_CREAT|O_TRUNC)
			or warn("sysopen: $!");
		syswrite($f, $res->content)
			or warn("syswrite: $!");
		close($f);
		$fetched++;
		$URLHash{$id} = undef;
	} else {
		if ($res->code == 404) {
			$nodata++;
			$NoData[$z][$x][$y] = 1
				if ($z < $maxzoom);
			warn($req->url, " ", length($res->content),
			    " bytes ", $res->status_line, "\n");
		} elsif ($res->code == 504) {
			$id = $async->add(getreq($ux, $uy, $z));
			$URLHash{$id} = [$z, $x, $y, $ux, $uy];
			$retries++;
		} elsif ($res->code == 503) {
			printf("%u/%u/%u (%s): %u - retrying\n",
			    $z, $x, $y, $req->url, $res->code);
			sleep(3600) if ($req->url =~ /www.google.com\/sorry/);
			$id = $async->add(getreq($ux, $uy, $z));
			$URLHash{$id} = [$z, $x, $y, $ux, $uy];
			$retries++;
		} else {
			warn($req->url, " ", length($res->content),
			    " bytes ", $res->status_line, "\n");
			$errors++;
		}
	}
}

sub
getreq($$$) {
	my ($x, $y, $z) = @_;
	my ($url, $req);

	$url = $WebMaps::Service->{UrlGen}($WebMaps::Service, $x, $y, $z);
	$req = HTTP::Request->new(GET => $url);
	$req->header(UA);

	return ($req);
}

sub
drain_queue()
{
	while (my ($res, $id) = $async->wait_for_next_response) {
		process_response($res, $id);
		info() if ($sigflag == 1);
	}
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

	printf("Zoom %u: bbox %u,%u,%u,%u\n", $z, $minx, $miny, $maxx, $maxy);

	my ($bminx, $bminy, $bmaxx, $bmaxy);
	($bminx, $bminy, $bmaxx, $bmaxy) = (TileNum($minx), TileNum($miny),
	    TileNum($maxx), TileNum($maxy));

	make_path("$cachedir/$z");

	$zdone = 1
		if (-r "$cachedir/$z/done");

	($fetched, $errors, $retries, $washere, $outofpoly, $nodata) = (0, 0, 0, 0, 0, 0);
	$start = time();
	$todo = ($bmaxy - $bminy + 1)*($bmaxx - $bminx + 1);

TILEX:	for (my $x = $bminx; $x <= $bmaxx; $x++) {
TILEY:	    for (my $y = $bminy; $y <= $bmaxy; $y++) {
		my ($ux, $uy);
		my $id;

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
		($ux, $uy) = $WebMaps::Service->{Readdr}($x,$y,$z);

		if (-r "$cachedir/$z/$ux/$uy") {
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

		$id = $async->add(getreq($ux, $uy, $z));
		$URLHash{$id} = [$z, $x, $y, $ux, $uy];

		while($async->to_return_count > MAXQUEUE) {
			my ($res, $id) = $async->next_response;
			process_response($res, $id);
			info() if ($sigflag == 1);
		}
		while($async->to_send_count >= MAXQUEUE) {
			drain_queue();
			if ($sndqoverflows++ > SLOWDOWN_LIM) {
				$sndqoverflows = 0;
				printf("Sleeping...\n");
				sleep(TIMEOUT);
			}
		}
	    }
	}

	drain_queue();

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
