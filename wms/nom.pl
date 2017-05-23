#!/usr/local/bin/perl -w

use strict;
use POSIX;

my (%latz, %lonz);	# not used

sub InitHashes() {	# not used
	my $i;

	$i = 0;
	for my $zone ("A" .. "U") {
		$latz{$zone}->{bottom} = $i;
		$latz{$zone}->{top} = $i + 4;
		$i += 4;
	}

	$i = -180;
	for my $zone (1 .. 60) {
		$lonz{$zone}->{left} = $i;
		$lonz{$zone}->{right} = $i + 6;
		$i += 6;
	}
}

my %revbet;
@revbet{("A" .. "U")} = (0 .. 20);

# Left, bottom, right, top of given named zone
sub lbrt($$) {
	my ($s, $n) = @_;
	my ($l, $b, $r, $t, $lat, $lon);

	# assuming 0S = 0N, 0E = 0W
	$r = ($n * 6) - 180;
	$l = $r - 6;
	if ($l < 0) {
		$l = abs($l);
		$r = abs($r);
		$lon = "W";
	} else {
		$lon = "E";
	}
	if ($s =~ /^X/) {
		$s = substr($s, 1);
		$lat = "S";
	} else {
		$lat = "N";
	}
	$b = $revbet{$s} * 4;
	$t = $b + 4;

	return $l . $lon . " " . $b . $lat . " " . $r . $lon . " " . $t . $lat;
}

my @alphabet = ('A' .. 'Z');	# last useful is U

sub nom($$) {
	my ($lat, $lon) = @_;
	my ($s, $n);

	return ($lat < 0) ? "x" : "" . $alphabet[int(abs($lat)/4)] . "-" .
	     ceil(($lon + 180) / 6);
}

while (<>) {
	# Zone request
	if (/^(x?[a-u])-?([0-9]{2})$/i && $2 <= 60) {
		printf("%s\n", lbrt(uc($1), $2));
	}
	# Decimal degrees, Garmin/Google style
	if (/^([NS])?([0-9]+(?:\.[0-9]*)?)\s+([EW])?([0-9]+(?:\.[0-9]*)?)$/i) {
		my ($lat, $lon);

		$lat = $2;
		$lon = $4;

		$lat = -$lat if (uc($3) eq "S");
		$lon = -$lon if (uc($1) eq "W");
		
		printf("decimal degrees %f %f square %s\n", $lon, $lat, nom($lat, $lon));
	}
	# TODO: degrees, minutes, decimal minutes
}
