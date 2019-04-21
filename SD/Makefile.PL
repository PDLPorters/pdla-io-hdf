use strict;
use warnings;
use ExtUtils::MakeMaker;

my $thispackage = q(PDLA::IO::HDF::SD);
my $package = [ qw(SD.pd SD), $thispackage ];

my $pdla = eval { require PDLA::Core::Dev };

my %pkghash;
# so can output its deps at least
eval {
  require ExtUtils::Depends;
  my $pkg = ExtUtils::Depends->new($thispackage, qw(PDLA Alien::HDF4));
  $pkg->add_pm(
      'SD.pm' => '$(INST_LIBDIR)/SD.pm',
  );
  $pkg->add_typemaps('../typemap.hdf');
  %pkghash = $pkg->get_makefile_vars;
};

undef &MY::postamble; # suppress warning
*MY::postamble = sub { PDLA::Core::Dev::pdlpp_postamble($package); } if $pdla;

WriteMakefile(
    NAME => $thispackage,
    OBJECT => 'SD$(OBJ_EXT) ',
    %pkghash,
    clean => {
        FILES => 'SD.pm SD.xs SD$(OBJ_EXT) SD.c',
    },
    dist => { 
        COMPRESS => 'gzip', 
        SUFFIX => 'gz'
    }, 
    (eval ($ExtUtils::MakeMaker::VERSION) >= 6.57_02 ? ('NO_MYMETA' => 1) : ()),
);
