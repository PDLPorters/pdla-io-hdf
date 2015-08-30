use strict;
use warnings;
use ExtUtils::MakeMaker;
use ExtUtils::Depends;
use PDLA::Core::Dev;

my $thispackage = q(PDLA::IO::HDF);
my $pkg = ExtUtils::Depends->new($thispackage, qw(Alien::HDF4));
$pkg->set_inc(PDLA_INCLUDE());
$pkg->add_typemaps(PDLA_TYPEMAP());
$pkg->add_pm(
    'HDF.pm' => '$(INST_LIBDIR)/HDF.pm',
);

WriteMakefile(
    NAME => $thispackage,
    VERSION_FROM => 'HDF.pm',
    $pkg->get_makefile_vars,
    'META_MERGE' => {
        "meta-spec" => { version => 2 },
        resources => {
            homepage => 'http://pdlporters.github.io',
            repository  => {
                url => 'git://github.com/PDLPorters/pdla-io-hdf',
                type => 'git',
                web => 'https://github.com/PDLPorters/pdla-io-hdf',
            },
        },
    },
    'CONFIGURE_REQUIRES' => {
      'ExtUtils::MakeMaker' => 0,
      'ExtUtils::Depends' => '0.402',
      'Alien::HDF4' => 0,
      'PDLA::Core' => 0,
    },
    'BUILD_REQUIRES' => {
      'PDLA::Core' => 0,
    },
    'TEST_REQUIRES' => {
      'PDLA::Core' => 0,
      'Test::More' => 0,
    },
);
