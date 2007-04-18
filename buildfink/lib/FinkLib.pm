# A library of functions for interacting with Fink

#Copyright (c) 2005 Apple Computer, Inc.  All Rights Reserved.
#
#This program is free software; you can redistribute it and/or modify
#it under the terms of the GNU General Public License as published by
#the Free Software Foundation; either version 2 of the License, or
#(at your option) any later version.
#
#This program is distributed in the hope that it will be useful,
#but WITHOUT ANY WARRANTY; without even the implied warranty of
#MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#GNU General Public License for more details.
#
#You should have received a copy of the GNU General Public License
#along with this program; if not, write to the Free Software
#Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

package FinkLib;
use strict;
use warnings;

our($FinkDir, $FinkConfig, $ERR);

# Initialize the Fink API
sub initFink($) {
  $FinkDir = shift;

  unshift @INC, $FinkDir . "/lib/perl5";
  require Fink::Config;
  require Fink::Services;
  require Fink::Package;
  require Fink::PkgVersion;
  require Fink::VirtPackage;
  require Fink::Status;
  require Fink::Validation;

  $ENV{PATH} = "$FinkDir/bin:$FinkDir/sbin:/bin:/sbin:/usr/bin:/usr/sbin:/usr/X11R6/bin";
  $ENV{PERL5LIB} = "$FinkDir/lib/perl5:$FinkDir/lib/perl5/darwin";

  $FinkConfig = Fink::Services::read_config("$FinkDir/etc/fink.conf");
  Fink::Config::set_options({Verbose => 3, KeepBuildDir => 1});
  readPackages();

  return $FinkConfig;
}

# Make sure all essential packages are installed
sub installEssentials {
  # This actually breaks stuff because dpkg gets linked to libgettext3
  # instead of gettext.
  return;

  my @essentials = Fink::Package->list_essential_packages();
  my $pid = fork();
  if ($pid) {
    wait();
  } else {
    close(STDIN);
    system("fink", "-y", "rebuild", @essentials);
    system("fink", "-y", "reinstall", @essentials);
  }
}

sub readPackages {
  $Fink::Status::the_instance ||= Fink::Status->new();
  $Fink::Status::the_instance->read();

  eval {
    Fink::Package->forget_packages(2, 0);
  };
  if ($@ and $@ =~ /new API for forget_packages/) {
    Fink::Package->forget_packages({disk => 1});
  } elsif ($@) {
    die $@;
  }
  Fink::Package->require_packages();
}

# Purge packages we may have previously built
sub purgeNonEssential {
  my @essentials = map { quotemeta($_) } Fink::Package->list_essential_packages();
  my $re = "^(?:" . join("|", @essentials) . ")\$";

  readPackages();

  my @packages = Fink::Package->list_packages();
  my @purgelist;
  foreach my $pkgname (@packages) {
    next if $pkgname =~ /$re/i;
    next if Fink::VirtPackage->query_package($pkgname);

    my $obj;
    eval {
      $obj = Fink::Package->package_by_name($pkgname);
    };
    next if $@ or !$obj;
    next unless $obj->is_any_installed();
    my $vo = objForPackageNamed($pkgname);
    next if !$vo or $vo->is_type('dummy');

    push @purgelist, $pkgname;
  }

  system("dpkg --purge " . join(" ", @purgelist) . " 2>&1 | grep -v 'not installed'") if @purgelist;
}


# Get either the name or email address from the value of the maintainer field
sub maintParse {
  my $maint = shift;
  my($name, $email);

  if ($maint =~ m/^(.*) <(.*)>/) {
    ($name, $email) = ($1, $2);
    $name =~ s/"//g;
  } else {
    ($name, $email) = ("", $maint);
  }
  return($name, $email);
}
sub maintName { return (maintParse(shift))[0]; }
sub maintEmail { return (maintParse(shift))[1]; }

# Take a list of packages, and return it arranged by maintainer.
# Returns a hash of listrefs.  Hash keys are maintainers.
sub sortPackagesByMaintainer {
  my %maints;
  foreach my $pkg (@_) {
    my $obj = objForPackageNamed($pkg) or next;
    my $maint = "None <fink-devel\@lists.sourceforge.net>";
    if ($obj->has_param('maintainer')) {
      $maint = $obj->param('maintainer');
      # RangerRick has one email per package, but we want them clustered for maintindex
      $maint =~ s/<.*\@fink.racoonfink\.com>/<rangerrick\@fink.racoonfink.com>/;
    }

    $maints{$maint} ||= [];
    push @{$maints{$maint}}, $pkg;
  }

  return %maints;
}

# Get split-offs of a package
sub getRelatives {
  my $obj = shift or return;

  # _relatives has been replaced by a real method in
  # Fink CVS.
  my @relatives = $obj->can("get_relatives") ? $obj->get_relatives() : @{$obj->{_relatives} || []};
  return @relatives;
}

# Buildlocks are how Fink stops a package from being built twice
# at the same time.  They can get left over if the system crashes
# while building a package.
sub removeBuildLocks {
  foreach my $pkgname (Fink::Package->list_packages()) {
    next unless $pkgname =~ /^fink-buildlock-.*/;
    system("dpkg", "-r", $pkgname);
  }
}

# Get a flat list of things which depend on this package, and things which depend on those, &c.
sub getDependentsRecursive {
  my($pkgname, $depmap, $seen) = @_;
  $seen ||= {$pkgname => 1};

  my @ret;
  foreach my $dep (keys %{$depmap->{$pkgname}}) {
    next if $seen->{$dep};
    $seen->{$dep} = 1;
    push @ret, $dep;
    push @ret, getDependentsRecursive($dep, $depmap, $seen);
  }

  return @ret;
}

# Take a list of package names and filter out the ones which are split-offs.
# When we have a split-off in the list, replace it with its parent and suppress
# any further instances of members of that family.  This preserves our dependency
# ordering.
sub filterSplitoffs {
  my(@pkglist) = @_;
  my @ret;
  my %got_families;

  foreach my $pkgname (@pkglist) {
    next if $got_families{$pkgname};

    my $pkgobj = objForPackageNamed($pkgname) or next;
    if ($pkgobj->{parent}) {
      my $parent = $pkgobj->can("get_parent") ? $pkgobj->get_parent()->get_name() : $pkgobj->{parent}->get_name();

      next if $got_families{$parent};
      $got_families{$parent} = 1;
      push @ret, $parent;
    } else {
      $got_families{$pkgname} = 1;
      push @ret, $pkgname;
    }
  }

  return @ret;
}

sub objForPackageNamed {
  my $name = shift;
  my $pkgobj;
  eval {
    # Exception thrown to indicate error.
    # provides => return causes a Fink::Package object to be returned
    # instead of a Fink::PkgVersion for virtual packages; without it,
    # an interactive-only prompt asks for user input.
    $pkgobj = Fink::PkgVersion->match_package($name, provides => 'return');
  };
  if($@) {
    $ERR = $@;
    warn "Couldn't get package for $name: $@\n";
  } elsif($pkgobj and $pkgobj->isa("Fink::PkgVersion")) {
    $ERR = "";
    return $pkgobj;
  }

  $ERR = "Package doesn't exist.";
  return;
}

1;
