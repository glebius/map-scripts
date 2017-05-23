#!/usr/local/bin/perl

use strict;
use IPC::Open2;
use MyGDALtools;

local *RD;
die("Usage: $0 map_file\n") unless $#ARGV > -1;

my $GCPS = ReadGCPs($ARGV[0]);
my ($x, $y, $w, $h) = ClipRectangle($GCPS);
printf("%d %d %d %d\n", $x, $y, $w, $h);
