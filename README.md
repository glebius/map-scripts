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

wms/			- WMS management scripts, used to build layers for
			  mapserver. This stuff is strongly focused on building
			  a congiguous slippy map of Soviet Military maps, that
			  can be downloaded from different sources (e.g.
			  rutracker.org, poehali.org). Maps quality varies, and
			  they all are in different image formats, etc. So, the
			  strategy is: first, merge multiple sheets belonging
			  to the same projection sheet (рус. лист) into single
			  file; second, provide WMS service that brings all
			  these sheets as congiguous slippy map. To avoid
			  conversion of downloaded pre-merged files, this may
			  be achieved as virtual conversion. Finally generate
			  .shp file embracing this all and configure it in the
			  mapserver.
	Makefile	- Having all the merges sheets in place, build .vrts
			  and final index.shp.
	nom.pl		- Convert from Soviet sheet name to Lat/Lon of corners.
			  Vice versa conversion seems to be not done yet?
	gs.map		- Sample mapserer file to serve the resulting
			  index.shp.

wms/merge		- Having mosaic of georeferenced sheets, that belong to
			  the same projection sheet, merge them into one file.
			  Usually used on stuff taken from poehali.org.
	MyGDALtools.pm	- Gist code for get-corners.pl.
	get-corners.pl	- Take out those GCPs that belong to corners of sheet.
	gs-merge.sh	- Merge pile of small sheets into big one using GDAL.
