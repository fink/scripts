#!/usr/bin/perl -w
#
# dist-module.pl - make release tarballs and info files for one code module
#
# Fink - a package manager that downloads source and installs it
# Copyright (c) 2001 Christoph Pfisterer
# Copyright (c) 2001-2011 The Fink Package Manager Team
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

#my $gitroot='git@github.com:fink/';
my $github_url='https://github.com/fink/fink/tarball';
my $cvsroot=':pserver:anonymous@fink.cvs.sourceforge.net:/cvsroot/fink';
my $distribution = "10.4";  #default value
my $vcstype='CVS';


### init

sub print_usage_and_exit {
	print "Usage: $0 [--cvs | --github] <module> <version-number> [<temporary-directory> [<tag>]]\n";
	exit 1;
}

&print_usage_and_exit() if ($#ARGV < 1);

# The first (optional) parameter can be used to specify the VCS (version control system)
# to be used. We currently support two choices:
# 1) --cvs gets the code from the Fink SF.net CVS repository
# 2) --github gets the code from the Fink GitHub git repository
# TODO: Consider adding a third option "--git=URI" which grabs everything from
# a (local or remote) git repository using "git archive --remote=URI"
if ($ARGV[0] eq '--cvs') {
	shift;
	$vcstype = 'CVS';
} elsif ($ARGV[0] eq '--github') {
	shift;
	$vcstype = 'github';
}

&print_usage_and_exit() if ($#ARGV < 1);

#print "Running in $vcstype mode\n";

my $module = shift;
my $version = shift;
my $tmpdir = shift || "/tmp";
my $tag = shift;

if (not defined($tag)) {
	$tag = "release_" . $version;
	$tag =~ s/\./_/g ;
	# TODO: For old releases, it makes sense to turn "." into "_", but for new stuff,
	# I would recommend going with releases-1.2.3 or even just v1.2.3.
	# It is in fact quite easy to convert all tags to the "new" scheme when
	# switching the repository.
	#if ($vcstype eq 'git') {
	#	$tag = "v" . $version;
	#}
}

my $modulename = $module;
$modulename =~ s/\//-/g ;
my $fullname = "$modulename-$version";

print "packaging $module release $version, tag $tag\n";

### setup temp directory

`mkdir -p $tmpdir`;
#cd $tmpdir
umask 022;

if (-d "$tmpdir/$fullname") {
	print "There is a left-over directory in $tmpdir.\n";
	print "Remove $fullname, then try again.\n";
	exit 1;
}

### grab code from version control

print "Exporting module $module, tag $tag from $vcstype:\n";

if ($vcstype eq 'CVS') {
	# Original command using CVS:
	`umask 022; cd $tmpdir; cvs -d "$cvsroot" export -r "$tag" -d $fullname $module`;

	if (not -d "$tmpdir/$fullname") {
		print "CVS export failed, directory $fullname doesn't exist!\n";
		exit 1;
	}

	### remove any .cvsignore files
	`find $tmpdir/$fullname -name .cvsignore -exec rm {} \\;`;

} elsif ($vcstype eq 'github') {

	`umask 022; wget $github_url/$tag -O $tmpdir/$tag.tar.gz`;

	if ($? or not -f "$tmpdir/$tag.tar.gz") {
		print "github download failed, could not retrieve remote data!\n";
		exit 1;
	}

	# We need to treat "submodules" like "fink/mirror" in a special way.
	# The first component ("fink" in the example) as a repository name,
	# while the remaining components specify a subdirectory.
	my @module_components = split /\//, $module;
	my $taropts='--strip-components '.  ($#module_components + 1);
	$taropts .= ' fink-' . (shift @module_components) . '-*/';
	$taropts .= join('/', @module_components);

	`mkdir -p $tmpdir/$fullname && /usr/bin/tar -xvf $tmpdir/$tag.tar.gz -C $tmpdir/$fullname $taropts`;

	if (not -d "$tmpdir/$fullname") {
		print "git export failed, directory $fullname doesn't exist!\n";
		exit 1;
	}

	### remove any .gitignore files
	# TODO: Really? There is only one, and it is harmless
	`find $tmpdir/$fullname -name .gitignore -exec rm {} \\;`;
	
#} elsif ($vcstype eq 'git') {
	# TODO: Add a mode which assumes that you have a checkout/clone of the fink
	# git repository, with all tags in it:
	#`umask 022; git archive --format=tar --prefix=$fullname/ -o $tmpdir/$fullname.tar $tag; cd $tmpdir; tar xf  $fullname.tar`;
	# It could also (optionally?) allow specifying a "remote" repository
	# via the git archive --remote option

	# TODO: Make this more robust, e.g. first check that we are in a proper checkout/clone of the fink repository,
	# and if not, generate a more meaningful error.
	# TODO: verify that the "git" is available in the first place

} else {
	# TODO: SVN mode?
	# For unknown/unsupported modes, just die here
	print "unknown version control system '$vcstype'!\n";
	exit 1;
}


### versioning

if (-f "$tmpdir/$fullname/VERSION") {
	open(OUT,">$tmpdir/$fullname/VERSION") or die "can't open $tmpdir/$fullname/VERSION";
	print OUT "$version\n";
	close(OUT);

	# Replace "stamp-cvs-live" file by a "stamp-rel-$version" file for those
	# modules that contain it (e.g "dists").
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

my $coda = <<CODA;
CustomMirror: <<
Primary: http://downloads.sourceforge.net/
nam-US: http://easynews.dl.sourceforge.net/sourceforge/
nam-US: http://superb-west.dl.sourceforge.net/sourceforge/
nam-US: http://superb-east.dl.sourceforge.net/sourceforge/
nam-US: http://voxel.dl.sourceforge.net/sourceforge/
asi-JP: http://jaist.dl.sourceforge.net/sourceforge/
asi-TW: http://nchc.dl.sourceforge.net/sourceforge/
aus-AU: http://internode.dl.sourceforge.net/sourceforge/
aus-AU: http://transact.dl.sourceforge.net/sourceforge/
aus-AU: http://waix.dl.sourceforge.net/sourceforge/
eur-CH: http://puzzle.dl.sourceforge.net/sourceforge/
eur-CH: http://switch.dl.sourceforge.net/sourceforge/
eur-DE: http://dfn.dl.sourceforge.net/sourceforge/
eur-DE: http://mesh.dl.sourceforge.net/sourceforge/
eur-FR: http://ovh.dl.sourceforge.net/sourceforge/
eur-IE: http://heanet.dl.sourceforge.net/sourceforge/
eur-IT: http://garr.dl.sourceforge.net/sourceforge/
eur-NL: http://surfnet.dl.sourceforge.net/sourceforge/
eur-UK: http://kent.dl.sourceforge.net/sourceforge/
sam-BR: http://ufpr.dl.sourceforge.net/sourceforge/
<<
CODA

# my $coda = "CustomMirror: <<\n";
# $coda .= " Primary: http://superb-west.dl.sourceforge.net/sourceforge/\n";
# $coda .= " Secondary: http://easynews.dl.sourceforge.net/sourceforge/\n";
# $coda .= " nam-US: http://superb-west.dl.sourceforge.net/sourceforge/\n";
# $coda .= " eur: http://eu.dl.sourceforge.net/sourceforge/\n";
# $coda .= "<<\n";

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
		print "Creating package description file $modulename$suffix.info:\n";
		$revision = ${$revisions}{$distro};

		&modify_description("$tmpdir/$fullname/$modulename.info.in","$tmpdir/$modulename$suffix.info","$tmpdir/$fullname.tar.gz","$tmpdir/$fullname","mirror:custom:fink/%n-%v.tar.gz",$distribution,$coda,$version,$revision);
	}
}

if (-f "$tmpdir/$fullname/$modulename-x86_64.info.in") {
	print "\n";
	print "Creating package description file $modulename-x86_64.info:\n";
	&modify_description("$tmpdir/$fullname/$modulename-x86_64.info.in","$tmpdir/$modulename-x86_64.info","$tmpdir/$fullname.tar.gz","$tmpdir/$fullname","mirror:custom:fink/%n-%v.tar.gz","10.5",$coda,$version,"46");
}


print "Done:\n";
print `ls -l $tmpdir/*.info*` . "\n";

exit 0;
