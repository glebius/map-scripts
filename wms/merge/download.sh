#!/bin/sh

map=$1
map2=$(echo ${map} | sed 's/-//')

for n in $(jot -w %3.3d 144); do
	fetch -o 100k--${map2}-${n}.map "http://satmaps.info/download-ref.php?s=100k&map=${map}-${n}"
done
for n in $(jot -w %3.3d 144); do
	fetch -o 100k--${map2}-${n}.gif "http://satmaps.info/download-map.php?s=100k&map=${map}-${n}"
done
