package PDLA::IO::HDF;

=head1 NAME

PDLA::IO::HDF - A PDLA interface to the HDF4 library.

=head1 SYNOPSIS

  use PDLA;
  use PDLA::IO::HDF;

  # Open file 'foo.hdf' with all hdf interface:
  my $HDF = PDLA::IO::HDF->new("foo.hdf");

  # You can call functions from either the SD or VS interfaces:
  $HDF->{SD}->SDget("Foo_data");
  $HDF->{VS}->VSgetnames();

  # To close the file:
  $HDF->close();

=head1 DESCRIPTION

This library provides functions to manipulate HDF files with the
SD, VS, and V HDF interfaces.

For more information on HDF, see http://hdf.ncsa.uiuc.edu/

The 'new' function of this package uses the 'new' functions for the
individual HDF interfaces. This allows you to use all of the interfaces
at one time (if you don't mind the extended syntax).

Actually using the HDF files comes down to using one of the particular 
interfaces, for that see the docs on those modules.

=cut

our $VERSION = '2.019102';
$VERSION = eval $VERSION;

use PDLA::Primitive;
use PDLA::Basic;

use PDLA::IO::HDF::SD;
use PDLA::IO::HDF::VS;

#
# Constants:
#

=head1 CONSTANTS

These constants are now implented using the perl 'use constant' pragma.

Previously, they were just scalars that were changeable (which is a no-no).

See constant(1) for more info on how to use these in your code.

=head2 Access Modes

=over 8

=item DFACC_READ

Open the file in read-only mode.

=item DFACC_WRITE

Open the file in write-only mode.

=item DFACC_CREATE

Clobber the file (create it if it doesn't exist, and then open with RW mode).

=item DFACC_ALL

Open the file in read-write mode.

=item DFACC_RDONLY

Same as DFACC_READ

=item DFACC_RDWR

Open the file in read-write mode.

=back

=cut

# Access modes:
use constant {
    DFACC_READ   => 1,
    DFACC_WRITE  => 2,
    DFACC_CREATE => 4,
    DFACC_ALL    => 7,
    DFACC_RDONLY => 1,
    DFACC_RDWR   => 3,
};

=head2 VS Interface Interlacing Modes

=over 8

=item FULL_INTERLACE

=item NO_INTERLACE

=back

=cut
# VS interlace modes:
use constant {
    FULL_INTERLACE => 0,
    NO_INTERLACE   => 1,
};

=head2 HDF4 Data Type Codes:

=over 8

=item DFNT_UCHAR

HDF's unsigned char ~= PDLA's byte

=item DFNT_CHAR

HDF's char ~= PDLA's byte

=item DFNT_FLOAT32

HDF's 32-bit float ~= PDLA's float

=item DFNT_FLOAT64

HDF's 64-bit float ~= PDLA's double

=item DFNT_INT8

HDF's 8-bit integer ~= PDLA's byte

=item DFNT_UINT8

HDF's 8-bit unsigned integer ~= PDLA's byte

=item DFNT_INT16

HDF's 16-bit integer ~= PDLA's short

=item DFNT_UINT16

HDF's 16-bit unsigned integer ~= PDLA's ushort

=item DFNT_INT32

HDF's 32-bit integer ~= PDLA's long

=item DFNT_INT64

HDF's 32-bit integer ~= PDLA's long

=back

=cut 
# HDF Data type numbers:
use constant {
    DFNT_UCHAR   =>  3,
    DFNT_CHAR    =>  4,
    DFNT_FLOAT32 =>  5,
    DFNT_FLOAT64 =>  6,
    DFNT_INT8    => 20,
    DFNT_UINT8   => 21,
    DFNT_INT16   => 22,
    DFNT_UINT16  => 23,
    DFNT_INT32   => 24,
    DFNT_INT64   => 25,
};

=head2 Misc. HDF Library Constants:

=over 8

=item MAX_NC_NAME

This is the max name length for SDS variables, attribtues, and just about anything else.

=item MAX_VAR_DIMS

This is the max number of dims a HDF variable can have.

=item VNAMELENMAX

Max length of V interface names.

=back

=cut 

# These are current with HDF4.2r1:
#

# Maximum Attr/SDS/VS name length:
use constant MAX_NC_NAME => 256;

# Maximum variable dims (use for alloc'ing mem for the low level calls that return dims:
use constant MAX_VAR_DIMS => 32;

# Max name len for VS interface:
use constant VNAMELENMAX => 64;

use constant FAIL => -1;

# Declaration of the different 'typemap' globals

# NOTE: Since the keys & values below are constants, we need the () around them:

#typemap pour convertir typePDLA->typeHDF
$SDtypeTMAP = {
    PDLA::byte->[0]   => (DFNT_UINT8), 
    PDLA::short->[0]  => (DFNT_INT16),
    PDLA::ushort->[0] => (DFNT_UINT16), 
    PDLA::long->[0]   => (DFNT_INT32),
    PDLA::float->[0]  => (DFNT_FLOAT32), 
    PDLA::double->[0] => (DFNT_FLOAT64), 
    #PDLA::byte->[0]   => $DFNT_UCHAR  ###attention PDLA::byte 2x
};

#typemap pour convertir typeHDF->typePDLA
$SDinvtypeTMAP = {
    (DFNT_INT8)    => sub { PDLA::byte(@_); }, #badtype
    (DFNT_UINT8)   => sub { PDLA::byte(@_); },
    (DFNT_INT16)   => sub { PDLA::short(@_); },
    (DFNT_UINT16)  => sub { PDLA::ushort(@_); },
    (DFNT_INT32)   => sub { PDLA::long(@_); },
    (DFNT_INT64)   => sub { PDLA::long(@_); }, #badtype
    (DFNT_FLOAT32) => sub { PDLA::float(@_); }, 
    (DFNT_FLOAT64) => sub { PDLA::double(@_); },
    (DFNT_UCHAR)   => sub { PDLA::byte(@_); },
    (DFNT_CHAR)    => sub { PDLA::byte(@_); } #badtype
};

$SDinvtypeTMAP2 = {
    (DFNT_INT8)    => PDLA::byte,
    (DFNT_UINT8)   => PDLA::byte,
    (DFNT_INT16)   => PDLA::short,
    (DFNT_UINT16)  => PDLA::ushort,
    (DFNT_INT32)   => PDLA::long,
    (DFNT_INT64)   => PDLA::long,
    (DFNT_FLOAT32) => PDLA::float, 
    (DFNT_FLOAT64) => PDLA::double,
    (DFNT_UCHAR)   => PDLA::byte,
    (DFNT_CHAR)    => PDLA::byte,
};

sub new
{
    my $type = shift;
    my $file = shift;
 
    my $obj = {};

    $obj->{SD} = PDLA::IO::HDF::SD->new( $file );
    $obj->{VS} = PDLA::IO::HDF::VS->new( $file );

    bless $obj, $type;
} # End of new()...

sub close
{
    my $self = shift;
    $self->{SD}->close;
    $self->{VS}->close;
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

perl(1), PDLA(1), PDLA::IO::HDF::SD(1), PDLA::IO::HDF::VS(1), constant(1).

=cut


