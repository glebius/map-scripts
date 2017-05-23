#!/bin/sh

for file in $1; do
	srcwin=$(./get-corners.pl $file);
	gdal_translate -of vrt -expand rgb -a_nodata 255 -srcwin $srcwin $file translated-$file.vrt
	gdalwarp -of vrt translated-$file.vrt warped-$file.vrt
done

gdalbuildvrt -hidenodata merged.vrt warped-*
rgb2pct.py merged.vrt merged-pct.tiff
gdal_translate -co tiled=yes -co blockxsize=256 -co blockysize=256 -co compress=deflate -co predictor=1 -co zlevel=9 merged-pct.tiff merged.tiff
