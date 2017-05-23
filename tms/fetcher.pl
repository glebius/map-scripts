#!/usr/local/bin/perl

use strict;
use Switch;

use WebMaps qw/:standard/;

sub 
usage() {
	die("Usage: $0 provider cachedir left,bottom,right,top\n");
};

usage() if ($#ARGV != 2);
usage() unless(@ARGV[2] =~ /(\d+(?:\.\d+)?),(\d+(?:\.\d+)?),(\d+(?:\.\d+)?),(\d+(?:\.\d+)?)/);

my($left, $bottom, $right, $top) = ($1, $2, $3, $4);

MapsInit(@ARGV[0], @ARGV[1]);

print BBoxFetch($left, $bottom, $right, $top);
