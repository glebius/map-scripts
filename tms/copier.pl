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

print BBoxCopy(@ARGV[2], $left, $bottom, $right, $top);
