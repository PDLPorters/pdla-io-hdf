use strict;
use warnings;
use ExtUtils::MakeMaker;
use ExtUtils::Depends;
use PDLA::Core::Dev;

my $thispackage = q(PDLA::IO::HDF::SD);
my $package = [ qw(SD.pd SD), $thispackage ];
my $pkg = ExtUtils::Depends->new($thispackage, qw(Alien::HDF4));
$pkg->set_inc(PDLA_INCLUDE());
$pkg->add_typemaps(PDLA_TYPEMAP());
$pkg->add_pm(
    'SD.pm' => '$(INST_LIBDIR)/SD.pm',
);

undef &MY::postamble; # suppress warning
*MY::postamble = sub { pdlpp_postamble($package); };

WriteMakefile(
    NAME => $thispackage,
    OBJECT => 'SD.o ',
    $pkg->get_makefile_vars,
    clean => {
        FILES => 'SD.pm SD.xs SD.o SD.c',
    },
    dist => { 
        COMPRESS => 'gzip', 
        SUFFIX => 'gz'
    }, 
    (eval ($ExtUtils::MakeMaker::VERSION) >= 6.57_02 ? ('NO_MYMETA' => 1) : ()),
);
