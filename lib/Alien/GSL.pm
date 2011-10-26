package Alien::GSL;

use strict;
use warnings;

our $VERSION = 0.03_04;
$VERSION = eval $VERSION;

use Carp;
use Alien::GSL::ConfigData;
use File::ShareDir 'dist_dir';
use File::chdir;
use List::MoreUtils 'uniq';

# if $location eq share_dir then the module was built in share_dir mode
our $share_dir = '';
eval {
  $share_dir = dist_dir('Alien-GSL') if (Alien::GSL::ConfigData->config('location') eq 'share_dir');
};

=head1 NAME 

Alien::GSL - Easy installation of the GSL library

=head1 DESCRIPTION

This module is meant to ease the install of the Gnu Scientific Library (GSL). It also provides version checking and build flags via the gsl-config utility.

=head1 SYNOPSIS

 use Alien::GSL;

 unless (Alien::GSL::require_gsl_version('1.15')) {
   die "This module requires at least GSL 1.15";
 }

=head1 INSTALLATION

L<Alien::GSL> uses the L<Module::Build> system for installation. Therefore the usual build process is

 perl Build.PL
 ./Build
 ./Build test
 ./Build install

N.B. the C<./> is not needed on some platforms, notably Windows.

During its build phase (i.e. C<./Build> or more properly C<./Build build> or most properly C<./Build code>) it will attempt the following, more or less in order (also depends on platform and availability):

=over 

=item *

Use a system installed copy of the GSL libraries, using the information provided by calling C<gsl-config>.

=item *

Download pre-compiled binaries of the GSL library and store using L<File::ShareDir>.

=item *

Download and build GSL libraries from source. This build process does not require the C<Build> script to be run with root privaledges. Then either:

=over

=item *

Install system-wide if possible (only for Linux, when run as root). 

=item *

Store using L<File::ShareDir>.

=back

=back

The above behaviors may be manipulated by passing ...

=head2 Build Flags

When running C<./Build>, certain command line flags may be passed, i.e. C<./Build --ShareDir>.

=over

=item C<--Version 1.15>

Specify a version of the GSL library to be installed (here C<1.15>). Without this flag, the highest (read: newest) version available will be used. If a supplied version cannot be found, the install will croak.

=item C<--ShareDir>

When this flag is given, C<File::ShareDir> will be used, even if a system install was possible (i.e. on Linux as root).

=item C<--Force>

When this flad is given, action will be taken, even if a system install of GSL is found. Note that this flag is not needed if C<--ShareDir> is used.

=item C<--Dir dir>

Specify a directory (here C<dir>) to download and build the library. This directory will not be removed later.

=item C<--TempDir /dev/shm>

Specify a location for the temporary build directory (here C</dev/shm/>, the ramdisk on Ubuntu Linux).

=item C<--GSLCheck>

When this flag is given, if GSL is to be built from source, also include C<make check> in the build phase (before C<make install>). Has no effect if GSL is not going to be built from source.

=back

=head1 NO EXPORTS

Currently this module does not export any functions or variables. Use instead the fully qualified symbol name, i.e. C<Alien::GSL::gsl_version()>.

=head1 INTERFACE STABILITY

This module is in an alpha state. The author hopes that major functionality will remain. The module now uses L<Module::Build> which allows the install functionality (download, build, install) to be platform specific and separated from the usage functionality described in the L<MODULE FUNCTIONS> section.

=head1 MODULE FUNCTIONS

These functions are basically a functional interface to the C<gsl-config> utility command.

=head2 C<gsl_version>

Takes no options, returns the version number of the installed GSL library.

=cut

sub gsl_version {
  my $version;

  if ($share_dir) {
    $version = Alien::GSL::ConfigData->config('version');
  } else {
    $version = qx/ gsl-config --version /;
    if ($?) {
      carp "Call to gsl-config --version failed: $!";
      $version = '';
    }

    chomp($version);
  }

  return $version;
}

=head2 C<require_gsl_version( [$version] )>

A wrapper around C<gsl_version()> which (optionally) takes a number specifying a minimum GSL version, returns the GSL version if it is greater than or equal to that specified. Returns zero otherwise. May also be called with zero as the version parameter, or no parameter at all, in which case the behavior is the same as C<gsl_version()>.

=cut

sub require_gsl_version {

  my $required = shift;
  $required ||= 0;

  my $have = gsl_version();

  if ($required == 0) {
    return $have if $have;
  } 

  if ($have >= $required) {
    return $have;
  }

  return 0;

}

=head2 C<gsl_prefix>

Takes no options, returns the "GSL installation prefix".

=cut

sub gsl_prefix {
  my $prefix;

  if ($share_dir) {
    return $share_dir;
  } else {
    $prefix = qx/ gsl-config --prefix /;
    if ($?) {
      carp "Call to gsl-config --prefix failed: $!";
      $prefix = '';
    }

    chomp($prefix);
  }

  return $prefix;
}

=head2 C<gsl_libs( [opts hash or hash reference] )>

Takes an optional hash or hash reference, returns "library linking information". A hash key C<cblas>, whose value is false will return the "library linking information, without cblas", though by default the cblas information is included.

=cut

sub gsl_libs {
  my %opts = (ref $_[0] eq 'HASH') ? %{ $_[0] } : @_;

  if (! defined $opts{cblas}) {
    $opts{cblas} = 1;
  }

  my $libs;
  if ($share_dir) {

    my @libs = uniq @{Alien::GSL::ConfigData->config('libs')};

    unless ($opts{cblas}) {
      @libs = grep { ! /cblas/ } @libs;
    }

    {
      local $CWD = $share_dir;
      push @CWD, 'lib';
      unshift @libs, '-L' . $CWD;
    }

    $libs = join(' ', @libs);
  } else {

    my $call = 'gsl-config --libs';

    unless ($opts{cblas}) {
      $call .= '-without-cblas';
    } 

    $libs = qx/ $call /;
    if ($?) {
      carp "Call to $call failed: $!";
    }

    chomp($libs);
  }

  return $libs;
}

=head2 C<gsl_cflags>

Takes no options, returns the "pre-processor and compiler flags".

=cut

sub gsl_cflags {
  my $cflags;

  if ($share_dir) {
    my @inc = uniq @{Alien::GSL::ConfigData->config('inc')};

    local $CWD = $share_dir;
    push @CWD, 'include';
    $cflags = "-I$CWD " . join(' ', @inc);

  } else {

    my $command = 'gsl-config --cflags';
    $cflags = qx/$command/;
    if ($?) {
      carp "Call to $command failed: $!";
    }

    chomp($cflags);
  }

  return $cflags;
}

=head2 C<gsl_pkgconfig_location>

Returns the path the folder containing C<gsl.pc> for use with the C<pkg-config> command. This file should be setup during installation, however, it must make a few guesses while doing so. Better to use the other C<gsl_*> commands provided herein when possible.

=cut

sub gsl_pkgconfig_location {
  my $pc_file = '';

  if ($share_dir) {
    local $CWD = $share_dir;
    push @CWD, qw/lib pkgconfig/;
    
    if (-e 'gsl.pc') {
      $pc_file = $CWD;
    } else {
      warn "pkg-config data (gsl.pc) is not where it should be: $CWD";
    }

  } else {
    warn "pkg-config data (gsl.pc) is not tracked for system-installed Alien::GSL";
  }

  return $pc_file;

}

=head1 TODO

=over

=item *

C<gsl-config> script (replaces executable for C<File::ShareDir> installs)

=over

=item *

Document with POD rather than usage statement (pod2usage?).

=item *

Figure out how to handle script and executable both being in path.

=item *

Figure out how to launch script on Windows using a C<gsl-config.bat>.

=back

=item *

Find a better download site for the compiled libraries.

=item *

Provide 64 bit libraries.

=item *

Allow build when C<make> exists (i.e. on strawberry).

=item *

Clean the C<share_dir> directory when C<ACTION_clean> is run.

=item *

Improve tests for C<Alien::GSL>.

=item *

Are tests possible for C<Module::Build> subclasses?

=back

=head1 SEE ALSO

=over

=item L<Math::GSL>

=item L<Math::GSLx::ODEIV2>

=item L<GSL|http://www.gnu.org/software/gsl/>

=item L<PDL>, L<website|http://pdl.perl.org> 

=back

=head1 SOURCE REPOSITORY

L<http://github.com/jberger/Alien-GSL>

=head1 AUTHOR

Joel Berger, E<lt>joel.a.berger@gmail.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2011 by Joel Berger

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;


