use strict;
use warnings;
use ExtUtils::MakeMaker;
use ExtUtils::Depends;
use PDLA::Core::Dev;

my $thispackage = q(PDLA::IO::HDF::VS);
my $package = [ qw(VS.pd VS), $thispackage ];
my $pkg = ExtUtils::Depends->new($thispackage, qw(Alien::HDF4));
$pkg->set_inc(PDLA_INCLUDE());
$pkg->add_typemaps(PDLA_TYPEMAP());
$pkg->add_pm(
    'VS.pm' => '$(INST_LIBDIR)/VS.pm',
);

undef &MY::postamble; # suppress warning
*MY::postamble = sub { pdlpp_postamble($package); };

WriteMakefile(
    NAME => $thispackage,
    OBJECT => 'VS.o ',
    $pkg->get_makefile_vars,
    clean => {
        FILES => 'VS.pm VS.xs VS.o VS.c',
    },
    dist => { 
        COMPRESS => 'gzip', 
        SUFFIX => 'gz', 
    },
);
