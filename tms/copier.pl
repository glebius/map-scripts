#!/usr/local/bin/perl

use strict;
use Switch;

use WebMaps qw/:standard/;

sub 
usage() {
	die("Usage: $0 provider from to left,bottom,right,top\n");
};

usage() if ($#ARGV != 3);
usage() unless(@ARGV[3] =~ /(\d+(?:\.\d+)?),(\d+(?:\.\d+)?),(\d+(?:\.\d+)?),(\d+(?:\.\d+)?)/);

my($left, $bottom, $right, $top) = ($1, $2, $3, $4);

MapsInit(@ARGV[0], @ARGV[1]);

sub BBoxCopy($$$$$) {
	my ($Dest, $minx, $miny, $maxx, $maxy) = @_;
	my $z = $Service->{Zoom};
	my ($bminx, $bminy, $bmaxx, $bmaxy);
	my ($x, $y, $ix, $iy);
	my ($missing, $copied, $errors);

	if (! -w $Dest) {
		return "can\'t write to $Dest\n";
	}

	($minx, $miny) = $Service->{Proj}($minx, $miny, $z);
	($maxx, $maxy) = $Service->{Proj}($maxx, $maxy, $z);

	# Perform a swap of corners, to make LonLat
	# bounding boxes work in positive srs.
	($minx, $maxx) = ($maxx, $minx) if ($minx > $maxx);
	($miny, $maxy) = ($maxy, $miny) if ($miny > $maxy);

	($bminx, $bminy, $bmaxx, $bmaxy) = (TileNum($minx), TileNum($miny),
	    TileNum($maxx), TileNum($maxy));

	for ($y = $bminy, $iy = 0; $y <= $bmaxy; $y++, $iy++) {
	    for ($x = $bminx, $ix = 0; $x <= $bmaxx; $x++, $ix++) {

		if (! -r "$CacheDir/$z/$x/$y") {
			$missing++;
			next;
		}

		make_path("$Dest/$z/$x");
		if (system("/bin/cp", "$CacheDir/$z/$x/$y",
		    "$Dest/$z/$x") != 0) {
			$errors++;
		} else {
			$copied++;
		}
	    }
	}

	return sprintf("Copied %u, missing %u, errors %u\n",
	    $copied, $missing, $errors);
}

print BBoxCopy(@ARGV[2], $left, $bottom, $right, $top);
