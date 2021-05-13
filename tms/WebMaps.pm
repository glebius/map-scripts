package WebMaps;

use strict;

our (@ISA, @EXPORT_OK, %EXPORT_TAGS);
BEGIN {
	require Exporter;
	@ISA = qw/Exporter/;
	@EXPORT_OK = qw/ProjInit MapsInit TileNum TileSize LatLon2Tile/;
	%EXPORT_TAGS = (standard => [@EXPORT_OK]);
}

use LWP;
use POSIX qw/pow tan asin/;
use File::Path qw/make_path/;
use Fcntl qw/:DEFAULT/;
use Cwd;

use constant PI => 3.14159265358979;
use constant TileSize => 256;		# same for Google and Yandex

use constant RADIUS_E => 6378137;	# radius of Earth at equator
use constant EQUATOR => 40075016.68557849; # equator length
use constant E => 0.0818191908426;	# eccentricity of Earth's ellipsoid

use constant UA => 'Mozilla/5.0 (X11; FreeBSD amd64; rv:5.0) Gecko/20100101 Firefox/5.0';

my %Services = (

    google => {
	UrlGen	=> \&GoogleUrlGen,
	Tmpl	=> 'http://khm1.google.com/kh/v=102&x=%u&y=%u&z=%u&s=%s',
	Proj	=> \&GoogleProj,
	Zoom	=> 17,
	rw	=> 1,
    },

    bing => {
	UrlGen	=> \&BingUrlGen,
	Tmpl	=> 'http://a0.ortho.tiles.virtualearth.net/tiles/a%s.jpeg?g=72',
	ResChk	=> \&BingResChk,
	Proj	=> \&GoogleProj,
	Zoom	=> 18,
	rw	=> 1,
    },

    yandex => {
	UrlGen	=> \&GenericUrlGen,
	Tmpl	=> 'http://sat02.maps.yandex.net/tiles?l=sat&v=3.177.0&x=%u&y=%u&z=%u&lang=ru_RU',
	Proj	=> \&YandexProj,
	Zoom	=> 17,
	rw	=> 1,
    },

    irs => {
	UrlGen	=> \&GenericUrlGen,
	Tmpl => 'http://maps.kosmosnimki.ru/TileService.ashx?Request=gettile&layerName=19195FD12B6F473684BF0EF115652C38&apikey=4018C5A9AECAD8868ED5DEB2E41D09F7&crs=epsg:3857&x=%d&y=%d&z=%d',
	Proj	=> \&GoogleProj,
	Zoom	=> 14,
	rw	=> 1,
    },

);

our $Service = undef;
our $CacheDir = undef;
our $UA = LWP::UserAgent->new;

# tile maths

sub NumTiles($) {
	my $z = shift;

	return 2 ** $z;
}

sub WorldSize($) {
	my $z = shift;

	return NumTiles($z) * TileSize;
}

sub PixelsPerLonDegree($) {
	my $z = shift;

	return WorldSize($z) / 360;
}

sub PixelsPerLonRadian($) {
	my $z = shift;

	return WorldSize($z) / (2 * PI);
}

sub Deg2Rad($) {
	my $d = shift;

	return ($d * PI / 180);
}

sub TileNum($) {
	my $x = shift;

	return int($x / TileSize);
}

# URL generators
sub GenericUrlGen($$$$) {
	my ($Service, $x, $y, $z) = @_;

	return sprintf($Service->{Tmpl}, $x, $y, $z);
}

# Google URL generator
sub GoogleUrlGen($$$$) {
	my ($Service, $x, $y, $z) = @_;
	my $s = substr('Galileo', 0, ($x*3+$y)%8);

	return sprintf($Service->{Tmpl}, $x, $y, $z, $s);
}

sub BingUrlGen($$$$) {
	my ($Service, $x, $y, $z) = @_;
	my ($osX, $osY, $prX, $prY);
	my $s = "";

	$z++;
	$prX = $prY = $osX = $osY = 2 ** ($z-2);

	for (my $i = 1; $i < $z; $i++) {
		$prX /= 2;
		$prY /= 2;
		if ($x < $osX) {
			$osX -= $prX;
			if ($y < $osY) {
				$osY -= $prY;
				$s .= '0';
			} else {
				$osY += $prY;
				$s .= '2';
			}
		} else {
			$osX += $prX;
			if ($y < $osY) {
				$osY -= $prY;
				$s .= '1';
			} else {
				$osY += $prY;
				$s .= '3';
			}
		}
	}

	return sprintf($Service->{Tmpl}, $s);
}

sub BingResChk($) {
	my $res = shift;

	return (0) if (length($res->content) == 1033 &&
	    $res->header('Content-type') eq "image/png");

	return (1);	
}

# Google projector
sub GoogleProj($$$) {
	my ($lon, $lat, $z) = @_;
	my ($x, $y, $t);

	$x = int(WorldSize($z)/2 + $lon * PixelsPerLonDegree($z));
	$t = sin(Deg2Rad($lat));
	$y = int(WorldSize($z)/2 -
	    log((1 + $t)/(1 - $t)) * PixelsPerLonRadian($z) / 2);

	return ($x, $y);
}

# Yandex projector
sub YandexProj($$$) {
	my ($lon, $lat, $z) = @_;
	my ($x, $y, $tmp, $pow);

	# convert coords to radians and zoom level to zoom factor
	$lon = Deg2Rad($lon);
	$lat = Deg2Rad($lat);
	$z = WorldSize($z)/EQUATOR;

	$x = int((RADIUS_E * $lon + EQUATOR/2) * $z);
	$tmp = tan(PI/4 + $lat/2);
	$pow = pow(tan(PI/4 + asin(E * sin($lat))/2), E);
	$y = int((EQUATOR/2 - (RADIUS_E * log($tmp/$pow))) * $z);

	return ($x, $y);
}

###############################################################################
# Public below
###############################################################################

sub ProjInit($) {
	my $service = shift;

	$service = lc($service);

	$Service = $Services{$service};

	die("Unknown service\n") if not defined $Service;
}

sub MapsInit($$) {
	my ($service, $cachedir) = @_;

	ProjInit($service);

	$UA->agent(UA);

	if (-d $cachedir) {
		$CacheDir = $cachedir;
		if (! -w $cachedir) {
			$Service->{rw} = 0;
		}
	}
};

sub LatLon2Tile($$) {
	my ($lat, $lon) = @_;

	my ($x, $y) = $Service->{Proj}($lon, $lat, $Service->{Zoom});
	($x, $y) = (TileNum($x), TileNum($y));

	return $Service->{UrlGen}($Service, $x, $y, $Service->{Zoom});
}

1;
