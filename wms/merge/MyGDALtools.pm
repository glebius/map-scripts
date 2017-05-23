package MyGDALtools;

use strict;

our (@ISA, @EXPORT);
BEGIN {
	require Exporter;
	@ISA = qw/Exporter/;
	@EXPORT= qw/ReadGCPs ClipRectangle/;
}

# Parse gdalinfo output on given file to return array of GCPs.
sub ReadGCPs($)
{
	my $filename = shift;
	my @GCPS;
	local *RD;

	open(RD, "gdalinfo $filename |") or die("can't fork: $!");
	while (<RD>) {
		my ($line, %gcp);

		# The lines we are interested at look like:
		# GCP[  0]: Id=, Info=
		#          (106,92) -> (276130.807221185,5322878.60371761,0)

		next unless ($_ =~ /^GCP\[/);
		$line = <RD>;
		next unless ($line =~ /\s+\(([0-9]+),([0-9]+)\) -> \(([0-9.]+),([0-9.]+),0\)/);
		$gcp{img_x} = $1;
		$gcp{img_y} = $2;
		$gcp{geo_x} = $3;
		$gcp{geo_y} = $4;
		push(@GCPS, \%gcp);
	}
	close(RD);
	return (\@GCPS);
}

# Finds the uppermost leftmost corner and lowermost rightmost corner
# in the supplied array of GCPs, and returns uppermost leftmost
# corner and width and height, suitable as -srcwin gdal_translate
# argument.
sub ClipRectangle($) {
	my $GCPS = shift;       # arrayref
	my ($ul, $lr);

	$ul = $lr = $GCPS->[0];

	foreach my $gcp (@$GCPS) {
		if ($gcp->{img_x} + $gcp->{img_y} <
		    $ul->{img_x} + $ul->{img_y}) {
			$ul = $gcp;
		}
		if ($gcp->{img_x} + $gcp->{img_y} >
		    $lr->{img_x} + $lr->{img_y}) {
			$lr = $gcp;
		}
	}

	return ($ul->{img_x}, $ul->{img_y},
	    $lr->{img_x} - $ul->{img_x}, $lr->{img_y} - $ul->{img_y});
}

1;
