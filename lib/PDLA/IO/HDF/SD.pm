package PDLA::IO::HDF::SD;

=head1 NAME

PDLA::IO::HDF::SD - PDLA interface to the HDF4 SD library.

=head1 SYNOPSIS

  use PDLA;
  use PDLA::IO::HDF::SD;

  #
  # Creating and writing an HDF file
  #

  # Create an HDF file:
  my $hdf = PDLA::IO::HDF::SD->new("-test.hdf");

  # Define some data
  my $data = sequence(short, 500, 5);

  # Put data in file as 'myData' dataset with the names
  #    of dimensions ('dim1' and 'dim2')
  $hdf->SDput("myData", $data , ['dim1','dim2']);

  # Put some local attributes in 'myData'
  #
  # Set the fill value to 0
  my $res = $hdf->SDsetfillvalue("myData", 0);
  # Set the valid range from 0 to 2000
  $res = $hdf->SDsetrange("myData", [0, 2000]);
  # Set the default calibration for 'myData' (scale factor = 1, other = 0)
  $res = $hdf->SDsetcal("myData");

  # Set a global text attribute
  $res = $hdf->SDsettextattr('This is a global text test!!', "myGText" );
  # Set a local text attribute for 'myData'
  $res = $hdf->SDsettextattr('This is a local text testl!!', "myLText", "myData" );

  # Set a global value attribute (you can put all values you want)
  $res = $hdf->SDsetvalueattr( PDLA::short( 20 ), "myGValue");

  # Set a local value attribute (you can put all values you want)
  $res = $hdf->SDsetvalueattr( PDLA::long( [20, 15, 36] ), "myLValues", "myData" );

  # Close the file
  $hdf->close();

  #
  # Reading from an HDF file:
  #

  # Open an HDF file in read only mode:
  my $hdf = PDLA::IO::HDF::SD->new("test.hdf");

  # Get a list of all datasets:
  my @dataset_list = $hdf->SDgetvariablename();

  # Get a list of the names of all global attributes:
  my @globattr_list = $hdf->SDgetattributenames();

  # Get a list of the names of all local attributes for a dataset:
  my @locattr_list = $hdf->SDgetattributenames("myData");

  # Get the value of local attribute for a dataset:
  my $value = $hdf->SDgetattribut("myLText","myData");

  # Get a PDLA var of the entire dataset 'myData':
  my $data = $hdf->SDget("myData");

  # Apply the scale factor of 'myData'
  $data *= $hdf->SDgetscalefactor("myData");

  # Get the fill value and fill the PDLA var in with BAD:
  $data->inplace->setvaltobad( $hdf->SDgetfillvalue("myData") );

  # Get the valid range of a dataset:
  my @range = $hdf->SDgetrange("myData");

  #Now you can do what you want with your data
  $hdf->close();


=head1 DESCRIPTION

This library provides functions to read, write, and manipulate
HDF4 files with HDF's SD interface.

For more information on HDF4, see http://hdf.ncsa.uiuc.edu/

There have been a lot of changes starting with version 2.0, and these may affect
your code. PLEASE see the 'Changes' file for a detailed description of what
has been changed. If your code used to work with the circa 2002 version of this
module, and does not work anymore, reading the 'Changes' is your best bet.

In the documentation, the terms dataset and SDS (Scientific Data Set) are used
interchangeably.

=cut

use PDLA;

require POSIX;

use FindBin;
use Alien::HDF4::Install::Files;
use Inline Pdlapp => 'DATA', name => __PACKAGE__,
  %{ Alien::HDF4::Install::Files->Inline('C') }, # EUD returns empty if !"C"
  # relative to t/ !
  typemaps => "$FindBin::Bin/../lib/PDLA/IO/HDF/typemap.hdf",
  ;

sub _pkg_name
    { return "PDLA::IO::HDF::SD::" . shift() . "()"; }

# Convert a byte to a char:
sub Byte2Char
{
    my ($strB) = @_;
    my $strC;
    for(my $i=0; $i<$strB->nelem; $i++)
    {
        $strC .= chr( $strB->at($i) );
    }
    return($strC);
} # End of Byte2Char()...

=head1 CLASS METHODS

=head2 new

=for ref

    Open or create a new HDF object.

=for usage

    Arguments:
        1 : The name of the file.
            if you want to write to it, prepend the name with the '+' character : "+name.hdf"
            if you want to create it, prepend the name with the '-' character : "-name.hdf"
            otherwise the file will be open in read only mode

    Returns the hdf object (die on error)

=for example

    my $hdf = PDLA::IO::HDF::SD->new("file.hdf");

=cut


sub new
{
    # General:
    my $type = shift;
    my $filename = shift;

    my $sub = _pkg_name( 'new' );

    my $debug = 0;

    my $self = {};

    if (substr($filename, 0, 1) eq '+')
    {   # open for writing
        $filename = substr ($filename, 1);      # chop off +
        $self->{ACCESS_MODE} = PDLA::IO::HDF->DFACC_WRITE + PDLA::IO::HDF->DFACC_READ;
    }
    if (substr($filename, 0, 1) eq '-')
    {   # Create new file
        $filename = substr ($filename, 1);      # chop off -
        print "$sub: Creating HDF File $filename\n"
            if $debug;
        $self->{ACCESS_MODE} = PDLA::IO::HDF->DFACC_CREATE;
        $self->{SDID} = PDLA::IO::HDF::SD::_SDstart( $filename, $self->{ACCESS_MODE} );
        my $res = PDLA::IO::HDF::SD::_SDend( $self->{SDID} );
        die "$sub: _ERR::Create\n"
            if( ($self->{SDID} == PDLA::IO::HDF->FAIL ) || ( $res == PDLA::IO::HDF->FAIL ));
        $self->{ACCESS_MODE} = PDLA::IO::HDF->DFACC_WRITE + PDLA::IO::HDF->DFACC_READ;
    }
    unless( defined( $self->{ACCESS_MODE} )  )
    {   # Default to Read-only access:
        $self->{ACCESS_MODE} = PDLA::IO::HDF->DFACC_READ;
    }
    $self->{FILE_NAME} = $filename;

    # SD interface:
    print "$sub: Loading HDF File $self->{FILE_NAME}\n"
        if $debug;

    $self->{SDID} = PDLA::IO::HDF::SD::_SDstart( $self->{FILE_NAME}, $self->{ACCESS_MODE} );
    die "$sub: _ERR::SDstart\n"
        if( $self->{SDID} == PDLA::IO::HDF->FAIL );

    my $num_datasets = -999;
    my $num_global_attrs = -999;
    my $res = _SDfileinfo( $self->{SDID}, $num_datasets, $num_global_attrs );
    die "$sub: ** sdFileInfo **\n"
        if($res == PDLA::IO::HDF->FAIL);

    foreach my $i ( 0 .. $num_global_attrs-1 )
    {
        print "$sub: Loading Global Attribute #$i\n"
            if $debug;

        my $attrname = " "x(PDLA::IO::HDF->MAX_NC_NAME+1);
        my $type = 0;
        my $count = 0;

        $res = _SDattrinfo( $self->{SDID}, $i, $attrname, $type, $count );
        die "$sub: ** sdAttrInfo **\n"
            if($res == PDLA::IO::HDF->FAIL);

        print "$sub: \$attrname = \'$attrname\'\n"
            if $debug;

        $self->{GLOBATTR}->{$attrname} = zeroes( $PDLA::IO::HDF::SDinvtypeTMAP2->{$type}, $count );
        $res = _SDreadattr( $self->{SDID}, $i, $self->{GLOBATTR}->{$attrname} );
        die "$sub: ** sdReadAttr **\n"
            if($res == PDLA::IO::HDF->FAIL);

        if( $type == PDLA::IO::HDF->DFNT_CHAR )
        {
            $self->{GLOBATTR}->{$attrname} = Byte2Char( $self->{GLOBATTR}->{$attrname} );
        }
    }

    my @dataname;
    foreach my $i ( 0 .. $num_datasets-1 )
    {
        print "$sub: Loading SDS #$i\n"
            if $debug;

        my $sds_id = _SDselect( $self->{SDID}, $i );
        die "$sub: ** sdSelect **\n"
            if($sds_id == PDLA::IO::HDF->FAIL);

        my $name = " "x(PDLA::IO::HDF->MAX_NC_NAME+1);
        my $rank = 0;
        my $dimsize = " "x( (4 * PDLA::IO::HDF->MAX_VAR_DIMS) + 1 );
        my $numtype = 0;
        my $num_attrs = 0;

        $res = _SDgetinfo($sds_id, $name, $rank, $dimsize, $numtype, $num_attrs);
        die "$sub: ** sdGetInfo **\n"
            if($res == PDLA::IO::HDF->FAIL);

        print "$sub: \$name = \'$name\'\n"
            if $debug;
        print "$sub: \$dimsize = \'$dimsize\'\n"
            if $debug;

        $self->{DATASET}->{$name}->{TYPE} = $numtype;
        $self->{DATASET}->{$name}->{RANK} = $rank;
        $self->{DATASET}->{$name}->{SDSID} = $sds_id;

        # Load up information on the dimensions (named, unlimited, etc...):
        #
        foreach my $j ( 0 .. $self->{DATASET}->{$name}->{RANK}-1 )
        {
            print "$sub: Loading SDS($i) Dimension #$j\n"
                if $debug;

            my $dim_id = _SDgetdimid( $sds_id, $j );
            die "$sub: ** sdGetDimId **\n"
                if($dim_id == PDLA::IO::HDF->FAIL);

            my $dimname = " "x(PDLA::IO::HDF->MAX_NC_NAME+1);
            my $size = 0;
            my $num_type = 0;
            my $num_dim_attrs = 0;

            $res = _SDdiminfo( $dim_id, $dimname, $size, $num_type, $num_dim_attrs );
            die "$sub: ** sdDimInfo **\n"
                if($res == PDLA::IO::HDF->FAIL);

            print "$sub: \$dimname = \'$dimname\'\n"
                if $debug;

            $self->{DATASET}->{$name}->{DIMS}->{$j}->{DIMID} = $dim_id;
	    $self->{DATASET}->{$name}->{DIMS}->{$j}->{SIZE} = $size;
	    $self->{DATASET}->{$name}->{DIMS}->{$j}->{NAME} = $dimname;

            # The size comes back as 0 if it has the HDF unlimited dimension thing going on:
            # So, lets figure out what the size is currently at:
            unless ( $size )
            {
		   $self->{DATASET}->{$name}->{DIMS}->{$j}->{REAL_SIZE} = _SDgetunlimiteddim( $sds_id, $j);
	    }
        }

        # Load up info on the SDS's attributes:
        #
        foreach my $j ( 0 .. $num_attrs-1 )
        {
            print "$sub: Loading SDS($i) Attribute #$j\n"
                if $debug;

            my $attrname = " "x(PDLA::IO::HDF->MAX_NC_NAME+1);
            my $type = 0;
            my $count = 0;

            $res = _SDattrinfo( $sds_id, $j, $attrname, $type, $count);
            die "$sub: ** sdAttrInfo **\n"
                if($res == PDLA::IO::HDF->FAIL);

            print "$sub: \$attrname = \'$attrname\'\n"
                if $debug;

            $self->{DATASET}->{$name}->{ATTRS}->{$attrname} =
                zeroes( $PDLA::IO::HDF::SDinvtypeTMAP2->{$type}, $count );

            $res = _SDreadattr( $sds_id, $j, $self->{DATASET}->{$name}->{ATTRS}->{$attrname} );
            die "$sub: ** sdReadAttr **\n"
                if($res == PDLA::IO::HDF->FAIL);

            # FIXME: This should be a constant
            if( $type == PDLA::IO::HDF->DFNT_CHAR )
            {
                $self->{DATASET}->{$name}->{ATTRS}->{$attrname} =
                    Byte2Char( $self->{DATASET}->{$name}->{ATTRS}->{$attrname} );
            }
        }
    }

    bless $self, $type;

    # Now that we're blessed, run our own accessors:

    # Default to using this (it's a good thing :)
    $self->Chunking( 1 );

    return $self;
} # End of new()...

=head2 Chunking

=for ref

    Accessor for the chunking mode on this HDF file.

    'Chunking' is an internal compression and tiling the HDF library can
        perform on an SDS.

    This variable only affects they way SDput() works, and is ON by default.

    The code modifications enabled by this flag automatically partition the
        dataset to chunks of at least 100x100 values in size. The logic on this
        is pretty fancy, and would take a while to doc out here. If you
        _really_ have to know how it auto-partitions the data, then look at
        the code.

    Someday over the rainbow, I'll add some features for better control of the
        chunking parameters, if the need arises. For now, it's just stupid easy
        to use.

=for usage

    Arguments:
        1 (optional): new value for the chunking flag.

=for example

    # See if chunking is currently on for this file:
    my $chunkvar = $hdf->Chunking();

    # Turn the chunking off:
    my $newvar = $hdf->Chunking( 0 );

    # Turn the chunking back on:
    my $newvar = $hdf->Chunking( 1 );

=cut


# See the changelog for more docs on this feature:
sub Chunking
{
    my $self = shift;
    my $var = shift;
    if( defined( $var ) )
    {
        $self->{CHUNKING} = $var ? 1 : 0;
    }
    return $self->{CHUNKING};
} # End of Chunking()...

=head2 SDgetvariablenames

=for ref

    get the list of datasets.

=for usage

    No arguments
    Returns the list of dataset or undef on error.

=for example

    my @DataList = $hdfobj->SDgetvariablenames();

=cut


sub SDgetvariablenames
{
    my($self) = @_;
    return keys %{$self->{DATASET}};
} # End of SDgetvariablenames()...
sub SDgetvariablename
{
    my $self = shift;
    return $self->SDgetvariablenames( @_ );
} # End of SDgetvariablename()...


=head2 SDgetattributenames

=for ref

    Get a list of the names of the global or SDS attributes.

=for usage

    Arguments:
        1 (optional) : The name of the SD dataset from which you want to get
            the attributes. This arg is optional, and without it, it will
            return the list of global attribute names.

    Returns a list of names or undef on error.

=for example

    # For global attributes :
    my @attrList = $hdf->SDgetattributenames();

    # For SDS attributes :
    my @attrList = $hdf->SDgetattributenames("dataset_name");

=cut


sub SDgetattributenames
{
    my($self, $name) = @_;
    if( defined( $name ) )
    {
        return( undef )
            unless defined( $self->{DATASET}->{$name} );
        return keys %{ $self->{DATASET}->{$name}->{ATTRS} };
    }
    else
    {
        return keys %{ $self->{GLOBATTR} };
    }
} # End of SDgetattributenames()...
# Wrapper (this is now defunct):
sub SDgetattributname
{
    my $self = shift;
    return $self->SDgetattributenames( @_ );
} # End of SDgetattributname()...

=head2 SDgetattribute

=for ref

    Get a global or SDS attribute value.

=for usage

    Arguments:
        1 : The name of the attribute.
        2 (optional): The name of the SDS from which you want to get the attribute
            value. Without this arg, it returns the global attribute value of that name.

    Returns an attribute value or undef on error.

=for example

    # for global attributs :
    my $attr = $hdf->SDgetattribute("attr_name");

    # for local attributs :
    my $attr = $hdf->SDgetattribute("attr_name", "dataset_name");

=cut


sub SDgetattribute
{
    my($self, $name, $dataset) = @_;
    if( defined($dataset) )
    {   # It's an SDS attribute:
        return( undef )
            unless defined( $self->{DATASET}->{$dataset} );
        return $self->{DATASET}->{$dataset}->{ATTRS}->{$name};
    }
    else
    {   # Global attribute:
        return( undef )
            unless defined( $self->{GLOBATTR}->{$name} );
        return $self->{GLOBATTR}->{$name};
    }
} # End of SDgetattribute()...
# Wrapper (this is now defunct):
sub SDgetattribut
{
    my $self = shift;
    return $self->SDgetattribute( @_ );
} # End of SDgetattribut()...

=head2 SDgetfillvalue

=for ref

    Get the fill value of an SDS.

=for usage

    Arguments:
        1 : The name of the SDS from which you want to get the fill value.

    Returns the fill value or undef on error.

=for example

    my $fillvalue = $hdf->SDgetfillvalue("dataset_name");

=cut


sub SDgetfillvalue
{
    my($self, $name) = @_;
    return( undef )
        unless defined( $self->{DATASET}->{$name} );
    return ($self->{DATASET}->{$name}->{ATTRS}->{_FillValue})->at(0);
} # End of SDgetfillvalue()...

=head2 SDgetrange

=for ref

    Get the valid range of an SDS.

=for usage

    Arguments:
        1 : the name of the SDS from which you want to get the valid range.

    Returns a list of two elements [min, max] or undef on error.

=for example

    my @range = $hdf->SDgetrange("dataset_name");

=cut


sub SDgetrange
{
    my($self, $name) = @_;
    return( undef )
        unless defined( $self->{DATASET}->{$name} );
    return $self->{DATASET}->{$name}->{ATTRS}->{valid_range};
} # End of SDgetrange()...

=head2 SDgetscalefactor

=for ref

    Get the scale factor of an SDS.

=for usage

    Arguments:
        1 : The name of the SDS from which you want to get the scale factor.

    Returns the scale factor or undef on error.

=for example

    my $scale = $hdf->SDgetscalefactor("dataset_name");

=cut


sub SDgetscalefactor
{
    my($self, $name) = @_;
    return( undef )
        unless defined( $self->{DATASET}->{$name} );

    return ($self->{DATASET}->{$name}->{ATTRS}->{scale_factor})->at(0);
} # End of SDgetscalefactor()...

=head2 SDgetdimsize

=for ref

    Get the dimensions of a dataset.

=for usage

    Arguments:
        1 : The name of the SDS from which you want to get the dimensions.

    Returns an array of n dimensions with their sizes or undef on error.

=for example

    my @dim = $hdf->SDgetdimsize("dataset_name");

=cut


sub SDgetdimsize
{
    my ($self, $name) = @_;
    return( undef )
        unless defined( $self->{DATASET}->{$name} );
    my @dims;
    foreach( sort keys %{ $self->{DATASET}->{$name}->{DIMS} } )
    {
        push @dims, $self->{DATASET}->{$name}->{DIMS}->{$_}->{SIZE};
    }

    return( @dims );
} # End of SDgetdimsize()...

=head2 SDgetunlimiteddimsize

=for ref

    Get the actual dimensions of an SDS with 'unlimited' dimensions.

=for usage

    Arguments:
        1 : The name of the SDS from which you want to the dimensions.

    Returns an array of n dimensions with the dim sizes or undef on error.

=for example

    my @dims = $hdf->SDgetunlimiteddimsize("dataset_name");

=cut


sub SDgetunlimiteddimsize
{
    my ($self, $name) = @_;

    return( undef )
        unless defined( $self->{DATASET}->{$name} );

    my @dim;
    foreach( sort keys %{$self->{DATASET}{$name}{DIMS}} )
    {
        if( $self->{DATASET}->{$name}->{DIMS}->{$_}->{SIZE} == 0 )
        {
            $dim[ $_ ] =
                $self->{DATASET}->{$name}->{DIMS}->{$_}->{REAL_SIZE};
        }
        else
        {
            $dim[ $_ ] =
                $self->{DATASET}->{$name}->{DIMS}->{$_}->{SIZE};
        }
    }
    return(@dim);
} # End of SDgetunlimiteddimsize()...
# Wrapper (this is now defunct):
sub SDgetdimsizeunlimit
{
    my $self = shift;
    return $self->SDgetunlimiteddimsize( @_ );
} # End of SDgetdimsizeunlimit()...

=head2 SDgetdimnames

=for ref

    Get the names of the dimensions of a dataset.

=for usage

    Arguments:
        1 : the name of a dataset you want to get the dimensions'names .

    Returns an array of n dimensions with their names or an empty list if error.

=for example

    my @dim_names = $hdf->SDgetdimnames("dataset_name");

=cut


sub SDgetdimnames
{
    my ($self, $name) = @_;

    return( undef )
        unless defined( $self->{DATASET}->{$name} );

    my @dims=();
    foreach( sort keys %{ $self->{DATASET}->{$name}->{DIMS} } )
    {
	push @dims,$self->{DATASET}->{$name}->{DIMS}->{$_}->{NAME};
    }
    return(@dims);
} # End of SDgetdimnames()...
sub SDgetdimname
{
    my $self = shift;
    return $self->SDgetdimnames( @_ );
} # End of SDgetdimname();

=head2 SDgetcal

=for ref

    Get the calibration factor from an SDS.

=for usage

    Arguments:
        1 : The name of the SDS

    Returns (scale factor, scale factor error, offset, offset error, data type), or undef on error.

=for example

    my ($cal, $cal_err, $off, $off_err, $d_type) = $hdf->SDgetcal("dataset_name");

=cut


sub SDgetcal
{
    my ($self, $name ) = @_;

    my ($cal, $cal_err, $off, $off_err, $type);

    return( undef )
        unless defined( $self->{DATASET}->{$name} );
    return( undef )
        unless defined( $self->{DATASET}->{$name}->{ATTRS}->{scale_factor} );

    $cal = $self->{DATASET}->{$name}->{ATTRS}->{scale_factor};
    $cal_err = $self->{DATASET}->{$name}->{ATTRS}->{scale_factor_err};
    $off = $self->{DATASET}->{$name}->{ATTRS}->{add_offset};
    $off_err = $self->{DATASET}->{$name}->{ATTRS}->{add_offset_err};
    $type = $self->{DATASET}->{$name}->{ATTRS}->{calibrated_nt};

    return( $cal, $cal_err, $off, $off_err, $type );
} # End of SDgetcal()...

=head2 SDget

=for ref

    Get a the data from and SDS, or just a slice of that SDS.

=for usage

    Arguments:
        1 : The name of the SDS you want to get.
        2 (optional): The start array ref of the slice.
        3 (optional): The size array ref of the slice (HDF calls this the 'edge').
        4 (optional): The stride array ref of the slice.

    Returns a PDLA of data if ok, PDLA::null on error.

    If the slice arguments are not given, this function will read the entire
        SDS from the file.

    The type of the returned PDLA variable is the PDLA equivalent of what was
        stored in the HDF file.

=for example

    # Get the entire SDS:
    my $pdldata = $hdf->SDget("dataset_name");

    # get a slice of the dataset
    my $start = [10,50,10];  # the start position of the slice is [10, 50, 10]
    my $edge = [20,20,20];   # read 20 values on each dimension from @start
    my $stride = [1, 1, 1];  # Don't skip values
    my $pdldata = $hdf->SDget( "dataset_name", $start, $edge, $stride );

=cut


sub SDget
{
    my($self, $name, $start, $end, $stride) = @_;
    my $sub = _pkg_name( 'SDget' );

    return PDLA::null
        unless defined( $self->{DATASET}->{$name} );

    unless( defined( $end ) )
    {   # \@end was not passed in, so we need to set everything else to defaults:
        ($start, $end) = [];
        my @dimnames=$self->SDgetdimnames($name);
	for my $dim (0 .. $#dimnames)
        {
            my $use_size = $self->{DATASET}->{$name}->{DIMS}->{$dim}->{SIZE}
                || $self->{DATASET}->{$name}->{DIMS}->{$dim}->{REAL_SIZE};

            $$end[ $dim ] = $use_size;
            $$start[ $dim ] = 0;
            $$stride[ $dim ] = 1;
        }
    }

    my $c_start = pack ("L*", @$start);
    my $c_end = pack ("L*", @$end);
    my $c_stride = pack ("L*", @$stride);
    #print STDERR "$sub: start:[".join(',',@$start)
    #    ."]=>$c_start end:[".join(',',@$end)
    #    ."]=>$c_end stride:[".join(',',@$stride)."]=>$c_stride\n";

    my $buff = zeroes( $PDLA::IO::HDF::SDinvtypeTMAP2->{$self->{DATASET}->{$name}->{TYPE}}, reverse @$end );

    my $res = _SDreaddata( $self->{DATASET}->{$name}->{SDSID}, $c_start, $c_stride, $c_end, $buff );
    if($res == PDLA::IO::HDF->FAIL)
    {
        $buff = PDLA::null;
        print "$sub: Error returned from _SDreaddata()!\n";
    }

    return $buff;
} # End of SDget()...

=head2 SDsetfillvalue

=for ref

    Set the fill value for an SDS.

=for usage

    Arguments:
        1 : The name of the SDS.
        2 : The fill value.

    Returns true on success, undef on error.

=for example

    my $res = $hdf->SDsetfillvalue("dataset_name",$fillvalue);

=cut


sub SDsetfillvalue
{
    my ($self, $name, $value) = @_;

    return( undef )
        unless defined( $self->{DATASET}->{$name} );

    $value = &{$PDLA::IO::HDF::SDinvtypeTMAP->{$self->{DATASET}->{$name}->{TYPE}}}($value);
    $self->{DATASET}->{$name}->{ATTRS}->{_FillValue} = $value;

    return( _SDsetfillvalue($self->{DATASET}->{$name}->{SDSID}, $value) + 1 );
} # End of SDsetfillvalue()...

=head2 SDsetrange

=for ref

    Set the valid range of an SDS.

=for usage

    Arguments:
        1 : The name of the SDS
        2 : an anonymous array of two elements : [min, max].

    Returns true on success, undef on error.

=for example

    my $res = $hdf->SDsetrange("dataset_name", [$min, $max]);

=cut


sub SDsetrange
{
    my ($self, $name, $range) = @_;

    return undef
        unless defined( $self->{DATASET}->{$name} );

    my $min = &{$PDLA::IO::HDF::SDinvtypeTMAP->{$self->{DATASET}->{$name}->{TYPE}}}($$range[0]);
    my $max = &{$PDLA::IO::HDF::SDinvtypeTMAP->{$self->{DATASET}->{$name}->{TYPE}}}($$range[1]);
    $range = &{$PDLA::IO::HDF::SDinvtypeTMAP->{$self->{DATASET}->{$name}->{TYPE}}}($range);
    $self->{DATASET}->{$name}->{ATTRS}->{valid_range} = $range;

    return( _SDsetrange($self->{DATASET}->{$name}->{SDSID}, $max, $min) + 1 );
} # End of SDsetrange()...

=head2 SDsetcal

=for ref

    Set the HDF calibration for an SDS.

    In HDF lingo, this means to define:
        scale factor
        scale factor error
        offset
        offset error

=for usage

    Arguments:
        1 : The name of the SDS.
        2 (optional): the scale factor (default is 1)
        3 (optional): the scale factor error (default is 0)
        4 (optional): the offset (default is 0)
        5 (optional): the offset error (default is 0)

    Returns true on success, undef on error.

    NOTE: This is not required to make a valid HDF SDS, but is there if you want to use it.

=for example

    # Create the dataset:
    my $res = $hdf->SDsetcal("dataset_name");

    # To just set the scale factor:
    $res = $hdf->SDsetcal("dataset_name", $scalefactor);

    # To set all calibration parameters:
    $res = $hdf->SDsetcal("dataset_name", $scalefactor, $scale_err, $offset, $off_err);

=cut


sub SDsetcal
{
    my $self = shift;
    my $name = shift;

    return( undef )
        unless defined( $self->{DATASET}->{$name} );

    $self->{DATASET}->{$name}->{ATTRS}->{scale_factor} = shift || 1;
    $self->{DATASET}->{$name}->{ATTRS}->{scale_factor_err} = shift || 0;
    $self->{DATASET}->{$name}->{ATTRS}->{add_offset} = shift || 0;
    $self->{DATASET}->{$name}->{ATTRS}->{add_offset_err} = shift || 0;
    # PDLA_Double is the default type:
    $self->{DATASET}->{$name}->{ATTRS}->{calibrated_nt} = shift || 6;

    return(
        _SDsetcal(
            $self->{DATASET}->{$name}->{SDSID},
            $self->{DATASET}->{$name}->{ATTRS}->{scale_factor},
            $self->{DATASET}->{$name}->{ATTRS}->{scale_factor_err},
            $self->{DATASET}->{$name}->{ATTRS}->{add_offset},
            $self->{DATASET}->{$name}->{ATTRS}->{add_offset_err},
            $self->{DATASET}->{$name}->{ATTRS}->{calibrated_nt}
        ) + 1);
} # End of SDsetcal()...

=head2 SDsetcompress

=for ref

    Set the internal compression on an SDS.

=for usage

    Arguments:
        1 : The name of the SDS.
        2 (optional): The gzip compression level ( 1 - 9 ). If not
            specified, then 6 is used.

    Returns true on success, undef on failure.

    WARNING: This is a fairly buggy feature with many version of the HDF library.
    Please just use the 'Chunking' features instead, as they work far better, and
    are more reliable.

=for example

    my $res = $hdf->SDsetfillvalue("dataset_name",$deflate_value);

=cut


sub SDsetcompress
{
    my ($self, $name) = @_;

    return( undef )
        unless defined( $self->{DATASET}->{$name} );

    # NOTE: Behavior change from the old version:
    #    it used to set to 6 if the passed value was greater than 8
    #    it now sets it to 9 if it's greater than 9.
    my $deflate = shift || 6;
    $deflate = 9
        if( $deflate > 9 );

    return( 1 + _SDsetcompress( $self->{DATASET}->{$name}->{SDSID}, $deflate ) );
} # End of SDsetcompress()...

=head2 SDsettextattr

=for ref

    Add a text HDF attribute, either globally, or to an SDS.

=for usage

    Arguments:
        1 : The text you want to add.
        2 : The name of the attribute
        3 (optional): The name of the SDS.

    Returns true on success, undef on failure.

=for example

    # Set a global text attribute:
    my $res = $hdf->SDsettextattr("my_text", "attribut_name");

    # Set a local text attribute for 'dataset_name':
    $res = $hdf->SDsettextattr("my_text", "attribut_name", "dataset_name");

=cut


sub SDsettextattr
{
    my ($self, $text, $name, $dataset) = @_;

    if( defined($dataset) )
    {
        return( undef )
            unless defined( $self->{DATASET}->{$dataset} );

        $self->{DATASET}->{$dataset}->{ATTRS}->{$name} = $text;
        return( _SDsetattr_text( $self->{DATASET}->{$dataset}->{SDSID}, $name, $text, length($text) ) + 1 );
    }

    # Implied else it's a global attribute:
    $self->{GLOBATTR}->{$name} = $text;
    return( _SDsetattr_text( $self->{SDID}, $name, $text, length($text) ) + 1);
} # End of SDsettextattr()...

=head2 SDsetvalueattr

=for ref

    Add a non-text HDF attribute, either globally, or to an SDS.

=for usage

    Arguments:
        1 : A pdl of value(s) you want to store.
        2 : The name of the attribute.
        3 (optional): the name of the SDS.

    Returns true on success, undef on failure.

=for example

    my $attr = sequence( long, 4 );

    # Set a global attribute:
    my $res = $hdf->SDsetvalueattr($attribute, "attribute_name");

    # Set a local attribute for 'dataset_name':
    $res = $hdf->SDsetvalueattr($attribute, "attribute_name", "dataset_name");

=cut


sub SDsetvalueattr
{
    my ($self, $values, $name, $dataset) = @_;

    if( defined($dataset) )
    {
        return( undef )
            unless defined( $self->{DATASET}->{$dataset} );

        $self->{DATASET}->{$dataset}->{ATTRS}->{$name} = $values;
        return( _SDsetattr_values(
                    $self->{DATASET}->{$dataset}->{SDSID}, $name, $values,
                    $values->nelem(), $PDLA::IO::HDF::SDtypeTMAP->{$values->get_datatype()} ) + 1);
    }
    # Implied else it's a global attribute:
    $self->{GLOBATTR}->{$name} = $values;
    return( _SDsetattr_values(
                $self->{SDID}, $name, $values,
                $values->nelem(), $PDLA::IO::HDF::SDtypeTMAP->{$values->get_datatype()} ) + 1);
} # End of SDsetvalueattr()...

=head2 SDsetdimname

=for ref

    Set or rename the dimensions of an SDS.

=for usage

    Arguments:
        1 : The name of the SDS.
        2 : An anonymous array with the dimensions names. For dimensions you want
            to leave alone, leave 'undef' placeholders.

    Returns true on success, undef on failure.

=for example

    # Rename all dimensions
    my $res = $hdf->SDsetdimname("dataset_name", ['dim1','dim2','dim3']);

    # Rename some dimensions
    $res = $hdf->SDsetdimname("dataset_name", ['dim1', undef ,'dim3']);

=cut


# FIXME: There are several problems with this:
#    - The return code is an aggregate, and not necessarily accurate
#    - It bails on the first error without trying the rest. If that is still
#        desired, then it should run the check first, and if it's ok, then actually
#        make the HDF library call.
sub SDsetdimname
{
    my ($self, $name, $dimname) = @_;

    return undef
        unless defined( $self->{DATASET}->{$name} );

    my $res = 0;
    foreach( sort keys %{$self->{DATASET}->{$name}->{DIMS}} )
    {
        return( undef )
            unless defined( $$dimname[ $_ ] );

        $res = _SDsetdimname(
            $self->{DATASET}->{$name}->{DIMS}->{$_}->{DIMID},
            $$dimname[ $_ ] ) + 1;
    }
    return( $res );
} # End of SDsetdimname()...

=head2 SDput

=for ref

    Write to a SDS in an HDF file or create and write to it if it doesn't exist.

=for usage

    Arguments:
        1 : The name of the SDS.
        2 : A pdl of data.
        3 (optional): An anonymous array of the dim names (only for creation)
        4 (optional): An anonymous array of the start of the slice to store
            (only for putting a slice)

    Returns true on success, undef on failure.

    The datatype of the SDS in the HDF file will match the PDLA equivalent as
        much as possible.

=for example

    my $data = sequence( float, 10, 20, 30 ); #any value you want

    # Simple case: create a new dataset with a $data pdl
    my $result = $hdf->SDput("dataset_name", $data);

    # Above, but also naming the dims:
    $res = $hdf->SDput("dataset_name", $data, ['dim1','dim2','dim3']);

    # Just putting a slice in there:
    my $start = [x,y,z];
    $res = $hdf->SDput("dataset_name", $data->slice("..."), undef, $start);

=cut


sub SDput
{
    my($self, $name, $data, $dimname_p, $from) = @_;

    my $sub = _pkg_name( 'SDput' );

    my $rank = $data->getndims();
    my $dimsize = pack ("L*", reverse $data->dims);

    # If this dataset doesn't already exist, then create it:
    #
    unless ( defined( $self->{DATASET}->{$name} ) )
    {
        my $hdf_type = $PDLA::IO::HDF::SDtypeTMAP->{$data->get_datatype()};

        my $res = _SDcreate( $self->{SDID}, $name, $hdf_type, $rank, $dimsize );
        return( undef )
            if ($res == PDLA::IO::HDF->FAIL);

        $self->{DATASET}->{$name}->{SDSID} = $res;
        $self->{DATASET}->{$name}->{TYPE} = $hdf_type;
        $self->{DATASET}->{$name}->{RANK} = $rank;

        if( $self->Chunking() )
        {
            # Setup chunking on this dataset:
            my @chunk_lens;
            my $min_chunk_size = 100;
            my $num_chunks = 10;
            my $total_chunks = 1;
            foreach my $dimsize ( $data->dims() )
            {
                my $chunk_size = ($dimsize + 9) / $num_chunks;
                my $num_chunks_this_dim = $num_chunks;
                if( $chunk_size < $min_chunk_size )
                {
                    $chunk_size = $min_chunk_size;
                    # Re-calc the num_chunks_per_dim:
                    $num_chunks_this_dim = POSIX::ceil( $dimsize / $chunk_size );
                }
                push(@chunk_lens, $chunk_size);
                $total_chunks *= $num_chunks_this_dim;
            }
            my $chunk_lengths = pack("L*", reverse @chunk_lens);

            $res = _SDsetchunk( $self->{DATASET}->{$name}->{SDSID}, $rank, $chunk_lengths );
            return( undef )
                if ($res == PDLA::IO::HDF->FAIL);

            $res = _SDsetchunkcache( $self->{DATASET}->{$name}->{SDSID}, $total_chunks, 0);
            return( undef )
                if ($res == PDLA::IO::HDF->FAIL);
        } # End of chunking section...
    } # End of dataset creation...

    my $start = [];
    my $stride = [];
    if( defined( $from ) )
    {
        $start = $from;
        foreach($data->dims)
            { push(@$stride, 1); }
    }
    else
    {   # $from was not defined, so assume we're doing all of it:
        foreach($data->dims)
        {
            push(@$start, 0);
            push(@$stride, 1);
        }
    }
    $start = pack ("L*", @$start);
    $stride = pack ("L*", @$stride);
    $data->make_physical();

    $res = _SDwritedata( $self->{DATASET}->{$name}->{SDSID}, $start, $stride, $dimsize, $data );
    return( undef )
        if ($res == PDLA::IO::HDF->FAIL);

    foreach my $j ( 0 .. $rank-1 )
    {
        # Probably not a good way to bail:
        my $dim_id = _SDgetdimid( $self->{DATASET}->{$name}->{SDSID}, $j );
        return( undef )
            if( $dim_id == PDLA::IO::HDF->FAIL);

        if( defined( @$dimname_p[$j] ) )
        {
            $res = _SDsetdimname( $dim_id, @$dimname_p[$j] );
            return( undef )
                if( $res == PDLA::IO::HDF->FAIL );
        }

        my $dimname = " "x(PDLA::IO::HDF->MAX_NC_NAME);
        my $size = 0;
        my $num_dim_attrs = 0;
        $res = _SDdiminfo( $dim_id, $dimname, $size, $numtype=0, $num_dim_attrs);

        return( undef )
            if ($res == PDLA::IO::HDF->FAIL);
        $self->{DATASET}->{$name}->{DIMS}->{$j}->{NAME} = $dimname;
        $self->{DATASET}->{$name}->{DIMS}->{$j}->{SIZE} = $size;
        $self->{DATASET}->{$name}->{DIMS}->{$j}->{DIMID} = $dim_id;
    }
    return( 1 );
} # End of SDput()...

=head2 close

=for ref

    Close an HDF file.

=for usage

    No arguments.

=for example

    my $result = $hdf->close();

=cut


# NOTE: This may not be enough, since there may be opened datasets as well! SDendaccess()!
sub close
{
    my $self = shift;
    my $sdid = $self->{SDID};
    $self = undef;
    return( _SDend( $sdid ) + 1);
} # End of close()...

sub DESTROY
{
    my $self = shift;
    $self->close;
} # End of DESTROY()...

=head1 CURRENT AUTHOR & MAINTAINER

Judd Taylor, Orbital Systems, Ltd.
judd dot t at orbitalsystems dot com

=head1 PREVIOUS AUTHORS

Patrick Leilde patrick.leilde@ifremer.fr
contribs of Olivier Archer olivier.archer@ifremer.fr

=head1 SEE ALSO

perl(1), PDLA(1), PDLA::IO::HDF(1).

=cut

1;

__DATA__

__Pdlapp__

pp_addhdr(<<'EOH');

#include <hdf.h>
#include <mfhdf.h>
#include <string.h>

#define PDLAchar pdl
#define PDLAuchar pdl
#define PDLAshort pdl
#define PDLAint pdl
#define PDLAlong pdl
#define PDLAfloat pdl
#define PDLAdouble pdl
#define PDLAvoid pdl
#define uchar unsigned char


#define COMP_CODE_NONE 0
#define COMP_CODE_RLE 1
#define COMP_CODE_SKPHUFF 3
#define COMP_CODE_DEFLATE 4

EOH

use FindBin;
use lib "$FindBin::Bin/../../../../../..";
require 'buildfunc.noinst';

#-------------------------------------------------------------------------
# Create low level interface from HDF SD header file.
#-------------------------------------------------------------------------

create_low_level (<<'EODEF');
#
# SDS Interface
#
int SDstart(const char *filename, int access_mode);
int SDfileinfo(int sd_id, int *ndatasets, int *global_attr);
int SDattrinfo(int s_id, int attr_index, char *attr_name, int *number_type, int *count);
#int SDreadattr(int s_id, int attr_index, void *data);
int SDreadattr(int s_id, int attr_index, PDLAvoid *data);
int SDgetinfo(int sds_id, char *sds_name, int *rank, int *dimsizes, int *number_type, int *nattrs);
int SDselect(int sd_id, int index);
int SDgetdimid(int sds_id, int dim_number);
int SDdiminfo(int dim_id, char *name, int *count, int *number_type, int *nattrs);
int SDnametoindex(int sd_id, const char *sds_name);
#int SDreaddata(int sds_id, int *start, int *stride, int *edge, void *buffer);
int SDreaddata(int sds_id, int *start, int *stride, int *edge, PDLAvoid *buffer);
#int SDsetfillvalue(int sds_id, const void *fill_val);
int SDsetfillvalue(int sds_id, const PDLAvoid *fill_val);
#int SDsetrange(int sds_id, const void *max, const void *min);
int SDsetrange(int sds_id, const PDLAvoid *max, const PDLAvoid *min);
#int SDwritedata(int sds_id, const int *start, const int *stride, const int *edge, const void *data);
int SDwritedata(int sds_id, const int *start, const int *stride, const int *edge, const PDLAvoid *data);
int SDsetexternalfile(int sds_id, const char *filename, int offset);
int SDsetdimstrs(int dim_id, const char *label, const char *unit, const char *format);
int SDsetdimscale(int dim_id, int count, int number_type, const void *data);
int SDsetdimname(int dim_id, const char *dim_name);
int SDsetdatastrs(int sds_id, const char *label, const char *unit, const char *format, const char *coordsys);
int SDsetcal(int sds_id, double cal, double cal_err, double offset, double offset_err, int number_type);
#int SDsetcal(int sds_id, float cal, float cal_err, float offset, float offset_err, int number_type);
int SDsetattr(int s_id, const char *attr_name, int num_type, int count, const void *values);
int SDreftoindex(int sd_id, int sds_ref);
int SDiscoordvar(int sds_id);
int SDidtoref(int sds_id);
int SDgetdimstrs(int dim_id, char *label, char *unit, char *format, int len);
int SDgetdimscale(int dim_id, void *data);
int SDgetdatastrs(int sds_id, char *label, char *unit, char *format, char *coordsys, int len);


#ORIG:
#int SDgetcal(int sds_id, double cal, double cal_err, double offset, double offset_err, double number_type);
#int SDgetcal(int sds_id, float cal, float cal_err, float offset, float offset_err, int number_type);
#int SDgetcal(int sds_id, double *cal, double *cal_err, float64 *offset, float64 *offset_err, int *number_type);

int SDendaccess(int sds_id);
int SDend(int sd_id);
int SDcreate(int sd_id, const char *name, int number_type, int rank, const int *dimsizes);

int SDwritechunk(int sds_id, const int* origin, const PDLAvoid *data);
int SDsetchunkcache(int sds_id, int maxcache, int flag);

EODEF

pp_addxs('',<<'ENDXS');

void
_HEprint(int level)
        CODE:
            HEprint(stderr, level);

int
_SDgetcal(sds_id, cal, cal_err, offset, offset_err, number_type)
                int sds_id
                double cal
                double cal_err
                double offset
                double offset_err
                int* number_type
        CODE:
            RETVAL = SDgetcal(sds_id, &cal, &cal_err, &offset, &offset_err, number_type);
        OUTPUT:
            RETVAL

void
UnpackSBigEndianPDLA(size, buff, p)
                int                size
                unsigned char      * buff
                PDLAint             * p
        CODE:
                int                i, INTtmp;
                unsigned char      bch1, bch2;
                int                * data;

                data = p->data;

                for(i=0; i<size; i++)
                {
                        bch1 = buff[i*2];
                        bch2 = buff[i*2+1];

                        INTtmp = (bch1 << 8) + bch2;

                        if( INTtmp >= 32768 )
                        { INTtmp -= 65536; }

                        data[i] = INTtmp;
                }
            OUTPUT:
                p

int
_SDsetcompress(sd_id, ldef);
                int                sd_id
                int                 ldef
        CODE:
                comp_info c_info;
                c_info.deflate.level = ldef;
                RETVAL = SDsetcompress(sd_id, COMP_CODE_DEFLATE, &c_info) + 1;
        OUTPUT:
                RETVAL

int
_SDsetchunk(sds_id, rank, chunk_lengths);
                int sds_id
                int rank
                int* chunk_lengths
        CODE:
            HDF_CHUNK_DEF c_def;
            int i;
            int32 status = FAIL;
            for(i = 0; i < rank; i++)
            {
                /* fprintf(stderr, "_SDsetchunk(): chunk_lengths[%d] = %d\n", i , chunk_lengths[i]); */
                c_def.chunk_lengths[i] = chunk_lengths[i];
                c_def.comp.chunk_lengths[i] = chunk_lengths[i];
            }
            c_def.comp.comp_type = COMP_CODE_DEFLATE;
            c_def.comp.cinfo.deflate.level = 6;
            status = SDsetchunk(sds_id, c_def, (HDF_CHUNK | HDF_COMP) );
            if( status == FAIL )
            {
                fprintf(stderr, "_SDsetchunk(): return status = %d\n", status);
                HEprint(stderr, 0);
            }
            RETVAL = status;
        OUTPUT:
            RETVAL

int
_SDinitchunk(sds_id, type, rank, chunk_lengths);
                int sds_id
                int type
                int rank
                int* chunk_lengths
        CODE:
            void* data = NULL;
            int* origin = NULL;
            int i;
            size_t size;
            int status;
            origin = HDgetspace( sizeof( int ) * rank );
            for( i = 0; i < rank; i++ )
                origin[i] = 0;
            /* Just use the largest datatype here: */
            size = DFKNTsize(type) * chunk_lengths[0];
            if( rank > 1 )
            {
                for( i = 1; i < rank; i++ )
                    size *= chunk_lengths[i];
            }
            data = HDgetspace( size );
            status = SDwritechunk(sds_id, origin, data);
            if( status == FAIL )
            {
                fprintf(stderr, "_SDinitchunk(): return status = %d\n", status);
                HEprint(stderr, 0);
            }
            HDfreespace( data );
            HDfreespace( origin );
            RETVAL = status;
        OUTPUT:
            RETVAL

int
Hishdf(filename);
                char*    filename
        CODE:
            RETVAL = Hishdf(filename);
        OUTPUT:
            RETVAL

int
_SDgetunlimiteddim(sds_id, dim);
                int                sds_id
                int                 dim
        CODE:
                char sds_name[250];
                int rank;
                int dimsizes[32];
                int num_type;
                int nattrs;
                RETVAL = SDgetinfo(sds_id, sds_name, &rank, dimsizes, &num_type, &nattrs) + 1;
                if(RETVAL==1){RETVAL = dimsizes[dim];}
        OUTPUT:
                RETVAL

int
_SDsetattr_text(s_id, name, text, size);
                int                s_id
                char                 * name
                char                * text
                int                 size
        CODE:
                RETVAL = SDsetattr(s_id, name, 4, size, text);
        OUTPUT:
                RETVAL

int
_SDsetattr_values(s_id, name, values, size, type);
                int                s_id
                char                 * name
                pdl                * values
                int                 size
                int                 type
        CODE:
                RETVAL = SDsetattr(s_id, name, type, size, values->data);
        OUTPUT:
                RETVAL

ENDXS

pp_done();
