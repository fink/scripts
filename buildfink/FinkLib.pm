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

our($FinkDir, $FinkConfig);

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

	$ENV{PATH} = "$FinkDir/bin:$FinkDir/sbin:/bin:/sbin:/usr/bin:/usr/sbin:/usr/X11R6/bin";
	$ENV{PERL5LIB} = "$FinkDir/lib/perl5:$FinkDir/lib/perl5/darwin";

	$FinkConfig = Fink::Services::read_config("$FinkDir/etc/fink.conf");
	Fink::Config::set_options({Verbose => 3, KeepBuildDir => 1});
	Fink::Package->require_packages();

	return $FinkConfig;
}

# Purge packages we may have previously built
sub purgeNonEssential {
	my @essentials = map { quotemeta($_) } Fink::Package->list_essential_packages();
	my $re = "^(?:" . join("|", @essentials) . ")\$";

	$Fink::Status::the_instance ||= Fink::Status->new();
	$Fink::Status::the_instance->read();

	my @packages = Fink::Package->list_packages();
	my @purgelist;
	foreach my $pkgname (@packages) {
		next if $pkgname =~ /$re/i;
		next if $pkgname =~ /^fink-buildlock/;
		next if Fink::VirtPackage->query_package($pkgname);

		my $obj;
		eval {
			$obj = Fink::Package->package_by_name($pkgname);
		};
		next if $@ or !$obj;
		next unless $obj->is_any_installed();

		push @purgelist, $pkgname;
	}

	system("dpkg --purge " . join(" ", @purgelist) . " 2>&1 | grep -v 'not installed'") if @purgelist;
}

1;
