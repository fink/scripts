#!/usr/bin/perl -w
#
# dist-module.pl - make release tarballs and info files for one CVS module
#
# Fink - a package manager that downloads source and installs it
# Copyright (c) 2001 Christoph Pfisterer
# Copyright (c) 2001-2006 The Fink Package Manager Team
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.
#

$| = 1;
use 5.008_001;  # perl 5.8.1 or newer required
use strict;

require Fink::Bootstrap;
import Fink::Bootstrap qw(&modify_description &read_version_revision);


### configuration

my $cvsroot=':ext:dmrrsn@fink.cvs.sourceforge.net:/cvsroot/fink';
my $distribution = "10.4";  #default value

### init

if ($#ARGV < 1) {
    print "Usage: $0 <module> <version-number> [<temporary-directory> [<tag>]]\n";
    exit 1;
}

my $module = shift;
my $version = shift;
my $tmpdir = shift || "/tmp";
my $tag = shift;

if (not defined($tag)) {
    $tag = "release_" . $version;
    $tag =~ s/\./_/g ;
}

my $modulename = $module;
$modulename =~ s/\//-/g ;
my $fullname = "$modulename-$version";

print "packaging $module release $version, CVS tag $tag\n";

### setup temp directory

`mkdir -p $tmpdir`;
#cd $tmpdir
umask 022;

if (-d "$tmpdir/$fullname") {
    print "There is a left-over directory in $tmpdir.\n";
    print "Remove $fullname, then try again.\n";
    exit 1;
}

### check code out from CVS

print "Exporting module $module, tag $tag from CVS:\n";
`umask 022; cd $tmpdir; cvs -d "$cvsroot" export -r "$tag" -d $fullname $module`;
if (not -d "$tmpdir/$fullname") {
    print "CVS export failed, directory $fullname doesn't exist!\n";
    exit 1;
}

### remove any .cvsignore files

`find $tmpdir/$fullname -name .cvsignore -exec rm {} \\;`;

### versioning

if (-f "$tmpdir/$fullname/VERSION") {
    open(OUT,">$tmpdir/$fullname/VERSION") or die "can't open $tmpdir/$fullname/VERSION";
    print OUT "$version\n";
    close(OUT);
if (-f "$tmpdir/$fullname/stamp-cvs-live") {
    `rm -f $tmpdir/$fullname/stamp-cvs-live`;
    `touch $tmpdir/$fullname/stamp-rel-$version`;
}
}

### roll the tarball

print "Creating tarball $fullname.tar:\n";
`rm -f $tmpdir/$fullname.tar $tmpdir/$fullname.tar.gz`;
`cd $tmpdir; gnutar -cvf $fullname.tar $fullname`;
print "Compressing tarball $fullname.tar.gz...\n";
`gzip -9 $tmpdir/$fullname.tar`;

if (not -f "$tmpdir/$fullname.tar.gz") {
    print "Packaging failed, $fullname.tar.gz doesn't exist!\n";
    exit 1;
}

### finish up

print "Done:\n";
print `ls -l $tmpdir/*.tar.gz` . "\n";

### create package description files

my $coda = "CustomMirror: <<\n";
$coda .= " Primary: http://west.dl.sourceforge.net/sourceforge/\n";
$coda .= " nam-US: http://us.dl.sourceforge.net/sourceforge/\n";
$coda .= " eur: http://eu.dl.sourceforge.net/sourceforge/\n";
$coda .= "<<\n";

my ($packageversion, $revisions) = read_version_revision("$tmpdir/$fullname");

my ($distro, $suffix, $revision);

if (-f "$tmpdir/$fullname/$modulename.info.in") {
    foreach $distro (keys %{$revisions}) {
	if ($distro eq "all") {
	    $suffix = "";
	# leave distribution at its default value
	} else {
	    $suffix = "-$distro";
	    $distribution = $distro;
	}
	print "\n";
	print "Creating package description file $modulename.info$suffix:\n";
	$revision = ${$revisions}{$distro};

    &modify_description("$tmpdir/$fullname/$modulename.info.in","$tmpdir/$modulename.info$suffix","$tmpdir/$fullname.tar.gz","$tmpdir/$fullname","mirror:custom:fink/%n-%v.tar.gz",$distribution,$coda,$version,$revision);

}
}

print "Done:\n";
print `ls -l $tmpdir/*.info*` . "\n";

exit 0;
