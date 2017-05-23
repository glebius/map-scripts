#!/usr/local/bin/perl

use strict;
use CGI qw/:standard/;
use Switch;
use WebMaps qw/:standard/;

switch (param('request')) {
case /getmap/i {
	my ($width, $height) = (param('width'), param('height'));
	my ($minx, $miny, $maxx, $maxy) = split(/,/, param('bbox'), 4);

	unless (defined($minx) && defined($miny) && defined($maxx) && defined($maxy)) {
		print header, h1('Not defined bbox parameter');
		exit(0);
	}

	unless (defined($width) && defined($height)) {
		print header, h1('Not defined height and width');
		exit(0);
	}

	switch (param('layers')) {
		case /^google$/i {
			MapsInit('Google', '/data/googlewms.cache');
		}
		case /^bing$/i {
			MapsInit('bing', '/data/bing.cache');
		}
		case /^yandex$/i {
			MapsInit('Yandex', '/data/yandexwms.cache');
		}
		case /^yandexLR$/i {
			MapsInit('YandexLR', '/data/yandexwms.cache');
		}
		case /^irs$/i {
			MapsInit('irs14', '/data/kosmosnimki.cache');
		}
		else {
			print header, h1('Unknown layer');
			exit (0);
		}
	}
	print header(-type => "image/jpeg");
	print BBoxImage($minx, $miny, $maxx, $maxy, $width, $height);
} else {
	print header, h1('Unknown request');
}
}
