# map-scripts
A poorly organized and poorly documented pile of scripts I use to manipulate TMS mosaics and GDAL based WMS maps

Table of contents:
tms/			- TMS management scripts
	osm2poly.pl	- convert .osm to .poly. This is not my code!
	WebMaps.pm	- Gist code for the below scripts.
	fetch-poly.pl	- fetch polygon of TMS from Bing/Google/Yandex.
			  Gets broken pretty often due to changes in the
			  services. Last tested May 2017 for Bing.
	fetcher.pl	- same as fetch-poly.pl, works on rectangle
	copier.pl	- Extract a (smaller) rectangular TMS catalog out
			  of a bigger one. Should be upgraded to support
			  polygons.
	web2wms.pl	- Run WMS server on top of TMS mosaic files, hasn't
			  been in use for many years, since JOSM supports
			  special TMSes natively. Most likely broken.
