#!/usr/bin/perl -w
#
# t/hdf_vgroup.t
#
# Tests Vgroup features of the HDF library.
#
# 29 March 2006
# Judd Taylor, USF IMaRS
#
use strict;
use PDLA;
use Test::More;

BEGIN
{
    use PDLA::Config;
    if ( $PDLA::Config{WITH_HDF} ) 
    {
        eval( " use PDLA::IO::HDF; " );
        if( $@ )
        {
            plan skip_all => "PDLA::IO::HDF module compiled, but not available.";
        }  
        else
        {
            plan tests => 10;
        }
    }
    else
    {
        plan skip_all => "PDLA::IO::HDF module not compiled.";
    }
}

use PDLA::IO::HDF::VS;

use PDLA::Config;
use File::Temp qw(tempdir);
my $tmpdir = tempdir( CLEANUP => 1 );

my $testfile = "$tmpdir/vgroup.hdf";

# Vgroup test suite

# TEST 1:
my $Hid = PDLA::IO::HDF::VS::_Hopen( $testfile, PDLA::IO::HDF->DFACC_CREATE, 2 );
ok( $Hid != -1 );

PDLA::IO::HDF::VS::_Vstart( $Hid );

my $vgroup_id = PDLA::IO::HDF::VS::_Vattach( $Hid, -1, "w" );
PDLA::IO::HDF::VS::_Vsetname( $vgroup_id, 'vgroup_name' );
PDLA::IO::HDF::VS::_Vsetclass( $vgroup_id, 'vgroup_class' );

# TEST 2:
my $vgroup_ref = PDLA::IO::HDF::VS::_Vgetid( $Hid, -1 );
ok( $vgroup_ref != PDLA::IO::HDF->FAIL );

# TEST 3:
my $name = "";
PDLA::IO::HDF::VS::_Vgetname( $vgroup_id, $name);
ok( $name eq "vgroup_name" );

# TEST 4:
my $class = "";
PDLA::IO::HDF::VS::_Vgetclass( $vgroup_id, $class);
ok( $class eq "vgroup_class" );

PDLA::IO::HDF::VS::_Vdetach( $vgroup_id );

PDLA::IO::HDF::VS::_Vend( $Hid );

# TEST 5:
ok( PDLA::IO::HDF::VS::_Hclose( $Hid ) );

# TEST 6:
my $vOBJ = PDLA::IO::HDF::VS->new( "+$testfile" );
ok( defined($vOBJ) );

# TEST 7:
ok( $vOBJ->Vcreate('10vgroup','vgroup_class2','vgroup_name') );

# TEST 8:
my @mains = $vOBJ->Vgetmains();
ok( scalar( @mains ) > 0 );

foreach my $Vmain ( @mains )
{
    # TEST 9:
    my @Vchildren = $vOBJ->Vgetchildren( $Vmain );
    ok( scalar( @Vchildren ) > 0 );    
    
    if( defined $Vchildren[0] )
    {
        foreach ( @Vchildren )
            { print "\tchild : $_\n"; }
    }
}

# TEST 10:
ok( $vOBJ->close() );

# Remove the test file:
# NOTE: This is needed by test 10
unlink( $testfile );

exit(0);

