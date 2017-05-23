CS2CS_CMD?=	/usr/local/bin/cs2cs
GDALINFO?=	/usr/local/bin/gdalinfo
GDALWARP?=	/usr/local/bin/gdalwarp
GDALTINDEX?=	/usr/local/bin/gdaltindex

GREP?=		/usr/bin/grep
SED?=		/usr/bin/sed -E
RM?=		/bin/rm -f --

NOMCALC?=	./nom.pl
PROJHINTS?=	ProjectionHints
INDEX?=		vrt-index

TOWGS?=		"+towgs84=23.92,-141.27,-80.9,0,0.35,0.82,-0.12"

CS2CS?=		${CS2CS_CMD} +proj=latlong +ellps=krass ${TOWGS} +to +init=epsg:4326 -f %.10f

VRTS=		o37-100k-ValentinAK.vrt \
		o38-100k-ValentinAK.vrt \
		k38-100k.vrt \
		k43-100k.vrt \
		k44-100k.vrt \
		l35-100k.vrt \
		l36-100k.vrt \
		l37-100k.vrt \
		l38-100k.vrt \
		l39-100k.vrt \
		l40-100k.vrt \
		l53-100k.vrt \
		l54-100k.vrt \
		m34-100k.vrt \
		m35-100k.vrt \
		m36-100k.vrt \
		m37-100k.vrt \
		m38-100k.vrt \
		m39-100k.vrt \
		m40-100k.vrt \
		m44-100k.vrt \
		m45-100k.vrt \
		m46-100k.vrt \
		m47-100k.vrt \
		m48-100k.vrt \
		m49-100k.vrt \
		m52-100k.vrt \
		m53-100k.vrt \
		m54-100k.vrt \
		m55-100k.vrt \
		n34-100k.vrt \
		n35-100k.vrt \
		n36-100k.vrt \
		n37-100k.vrt \
		n38-100k.vrt \
		n39-100k.vrt \
		n40-100k.vrt \
		n41-100k.vrt \
		n42-100k.vrt \
		n43-100k.vrt \
		n44-100k.vrt \
		n45-100k.vrt \
		n46-100k.vrt \
		n47-100k.vrt \
		n48-100k.vrt \
		n49-100k.vrt \
		n51-100k.vrt \
		n52-100k.vrt \
		n53-100k.vrt \
		n54-100k.vrt \
		n57-100k.vrt \
		o34-100k.vrt \
		o35-100k.vrt \
		o36-100k.vrt \
		o39-100k.vrt \
		o40-100k.vrt \
		o41-100k.vrt \
		o42-100k.vrt \
		o43-100k.vrt \
		o44-100k.vrt \
		o45-100k.vrt \
		o46-100k.vrt \
		o48-100k.vrt \
		o49-100k.vrt \
		o55-100k.vrt \
		o57-100k.vrt \
		o58-100k.vrt \
		p35_36-100k.vrt \
		p37_38-100k.vrt \
		p39_40-100k.vrt \
		p41_42-100k.vrt \
		p43_44-100k.vrt \
		p45_46-100k.vrt \
		p47_48-100k.vrt \
		p49_50-100k.vrt \
		q35_36-100k.vrt \
		q37_38-100k.vrt \
		q39_40-100k.vrt \
		q41_42-100k.vrt \
		q43_44-100k.vrt \
		q45_46-100k.vrt \
		r35_36-100k.vrt \
		r37_38-100k.vrt \
		r45_46-100k.vrt \
		r47_48-100k.vrt \
		s44-100k.vrt \
		s45_46-100k.vrt \
		s47_48-100k.vrt \
		s49_50-100k.vrt \
		t45_48-100k.vrt

.MAIN		: index

.SUFFIXES	: .ecw .vrt

.ecw.vrt	:
	@echo Building $(.TARGET)
	@PROJ=$$($(GREP) $(.TARGET) $(PROJHINTS) | $(SED) s/^$(.TARGET)\ *//); \
	if [ -z "$${PROJ}" ]; then					\
		PROJ=$$(CPL_DEBUG=ON $(GDALINFO) $(.PREFIX).ecw 2>&1 |	\
		    $(SED) -En s/^OGRCT:\ Source:\ //p);		\
	fi;								\
	if [ -z "$${PROJ}" ]; then					\
		echo no proj for $(.TARGET);				\
		exit 1;							\
	fi;								\
	if (echo $(.TARGET) | $(GREP) -c _ >/dev/null); then		\
		ZONE1=$$(echo $(.TARGET) |				\
		    $(SED) "s/^([a-z][0-9]+)_.*$$/\1/");		\
		ZONE2=$$(echo $(.TARGET) |				\
		    $(SED) "s/^([a-z])[0-9]+_([0-9]+).*/\1\2/");	\
		LB=$$(echo $${ZONE1} | $(NOMCALC) | cut -f 1,2 -d ' ' |	\
		    $(CS2CS) | cut -b 1-27);				\
		RT=$$(echo $${ZONE2} | $(NOMCALC) | cut -f 3,4 -d ' ' |	\
		    $(CS2CS) | cut -b 1-27);				\
	else								\
		ZONE=$$(echo $(.TARGET) |				\
		    $(SED) "s/^([a-z][0-9]+).*$$/\1/");			\
		LB=$$(echo $${ZONE} | $(NOMCALC) | cut -f 1,2 -d ' ' |	\
		    $(CS2CS) | cut -b 1-27);				\
		RT=$$(echo $${ZONE} | $(NOMCALC) | cut -f 3,4 -d ' ' |	\
		    $(CS2CS) | cut -b 1-27);				\
	fi;								\
	echo $(GDALWARP) -of vrt -dstalpha -s_srs "$${PROJ} $(TOWGS)" -t_srs	\
		"+init=epsg:4326" -te $${LB} $${RT} $(.PREFIX).ecw $(.TARGET); \
	$(GDALWARP) -of vrt -dstalpha -s_srs "$${PROJ} $(TOWGS)" -t_srs	\
		"+init=epsg:4326" -te $${LB} $${RT} $(.PREFIX).ecw $(.TARGET)

$(INDEX).shp	: $(VRTS)
		$(GDALTINDEX) $(INDEX).shp $(VRTS)

clean-index	:
		$(RM) $(INDEX).*

clean-vrts	:
		$(RM) $(VRTS)

clean		: clean-vrts clean-index

index		: $(INDEX).shp
