package WebMaps;

use strict;

our (@ISA, @EXPORT_OK, %EXPORT_TAGS);
BEGIN {
	require Exporter;
	@ISA = qw/Exporter/;
	@EXPORT_OK = qw/ProjInit TileNum TileSize LatLon2Tile UA/;
	%EXPORT_TAGS = (standard => [@EXPORT_OK]);
}

use WWW::Curl::Easy;
use POSIX qw/pow tan asin/;
use File::Path qw/make_path/;
use Fcntl qw/:DEFAULT/;
use Cwd;

use constant PI => 3.14159265358979;
use constant TileSize => 256;		# same for Google and Yandex

use constant RADIUS_E => 6378137;	# radius of Earth at equator
use constant EQUATOR => 40075016.68557849; # equator length
use constant E => 0.0818191908426;	# eccentricity of Earth's ellipsoid

use constant UA => 'JOSM/1.5 (17702 ru) FreeBSD Java/1.8.0_282';

my %Services = (

    google => {
	UrlGen	=> \&GoogleUrlGen,
	Proj	=> \&EPSG3857Proj,
	Zoom	=> 17,
    },

    bing => {
	UrlGen	=> \&BingUrlGen,
	RRList	=> [ 't0', 't1', 't2', 't3'],
	RRi	=> 0,
	Proj	=> \&EPSG3857Proj,
	Zoom	=> 18,
    },

    yandex => {
	UrlGen	=> \&YandexUrlGen,
	Proj	=> \&YandexProj,
	Zoom	=> 17,
    },

    irs => {
	UrlGen	=> \&KosmoUrlGen,
	Proj	=> \&EPSG3857Proj,
	Zoom	=> 14,
    },

    maxar => {
	Init	=> \&MaxarInit,
	UrlGen	=> \&MaxarUrlGen,
	Proj	=> \&EPSG3857Proj,
	Zoom	=> 17,
    },
);

our $Service = undef;
our $CacheDir = undef;

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
sub
YandexUrlGen($$$)
{
	my ($x, $y, $z) = @_;

	return sprintf('http://sat02.maps.yandex.net/tiles?l=sat&v=3.177.0&x=%u&y=%u&z=%u&lang=ru_RU', $x, $y, $z);
}

sub
GoogleUrlGen($$$)
{
	my ($x, $y, $z) = @_;
	my $s = substr('Galileo', 0, ($x*3+$y)%8);

	return sprintf('http://khm1.google.com/kh/v=102&x=%u&y=%u&z=%u&s=%s',
	    $x, $y, $z, $s);
}

sub
BingUrlGen($$$)
{
	my ($x, $y, $z) = @_;
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

	if (++$Service->{RRi} > $#{$Service->{RRList}}) {
		$Service->{RRi} = 0;
	}

	return sprintf(
	    'http://ecn.%s.tiles.virtualearth.net/tiles/a%s.jpeg?g=6438',
	    $Service->{RRList}->[$Service->{RRi}], $s);
}

sub
KosmoUrlGen($$$)
{
	my ($x, $y, $z) = @_;

	return sprintf('http://maps.kosmosnimki.ru/TileService.ashx?Request=gettile&layerName=19195FD12B6F473684BF0EF115652C38&apikey=4018C5A9AECAD8868ED5DEB2E41D09F7&crs=epsg:3857&x=%d&y=%d&z=%d',
	    $x, $y, $z);
}

sub
MaxarInit()
{
	my $curl = WWW::Curl::Easy->new;

	$Service->{apikey} = undef;
	$curl->setopt(CURLOPT_URL,
	    'https://josm.openstreetmap.de/mapkey/Maxar-Premium');
	$curl->setopt(CURLOPT_USERAGENT, UA);
	$curl->setopt(CURLOPT_WRITEDATA, \$Service->{apikey});

	my $rv = $curl->perform;
	if ($rv != 0) {
		die("Maxar API key fetch failed: " . $curl->strerror($rv) .
		    " " . $curl->errbuf . "\n");
	}
	if ($curl->getinfo(CURLINFO_HTTP_CODE) != 200) {
		die("Maxar API key fetch http code " .
		    $curl->getinfo(CURLINFO_HTTP_CODE));
	}
	chomp($Service->{apikey});
}

sub
MaxarUrlGen($$$)
{
	my ($x, $y, $z) = @_;

	$y = NumTiles($z) - 1 - $y;
	return sprintf('https://services.digitalglobe.com/earthservice/tmsaccess/tms/1.0.0/DigitalGlobe:ImageryTileService@EPSG:3857@jpg/%u/%u/%u.jpg?connectId=%s&foo=premium',
	    $z, $x, $y, $Service->{apikey});
}

sub EPSG3857Proj($$$) {
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

sub
ProjInit($) {
	my $service = shift;

	$service = lc($service);

	$Service = $Services{$service};

	die("Unknown service\n") if not defined $Service;

	$Service->{Init}() if defined($Service->{Init});
}

sub LatLon2Tile($$) {
	my ($lat, $lon) = @_;

	my ($x, $y) = $Service->{Proj}($lon, $lat, $Service->{Zoom});
	($x, $y) = (TileNum($x), TileNum($y));

	return $Service->{UrlGen}($Service, $x, $y, $Service->{Zoom});
}

1;
