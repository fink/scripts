#!/usr/bin/perl -w
#
# dist-module.pl - make release tarballs and info files for one code module
#
# Fink - a package manager that downloads source and installs it
# Copyright (c) 2001 Christoph Pfisterer
# Copyright (c) 2001-2013 The Fink Package Manager Team
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
use Getopt::Long;

my ($github,$localdir,$cvs);
my $usage=''; #Give usage message

require Fink::Bootstrap;
import Fink::Bootstrap qw(&modify_description &read_version_revision);

sub print_usage_and_exit {
	print "\nUsage:\n";
	print "\t$0 [ --github | --local=<local-clone> | --cvs ] <module> <version-number> [<temporary-directory> [<tag>]]\n";
	print "\n\t$0 --help\n\n";	
	exit 1;
}


### configuration

### init

my $result = GetOptions (
			'help' 		=> \$usage,
			'github' 	=> \$github,
			'local=s'	=> \$localdir,
			'cvs'		=> \$cvs,	
			);


# An option flag can be used to specify the VCS (version control system)
# to be used. We currently support three choices:
# 1) --github gets the code from the Fink GitHub git repository
# 2) --local=<local-clone> grabs everything from a local clone from the Fink Github git repository
# 3) --cvs gets the code from the Fink SourceForge cvs repository
# The current default is --github.
# TODO: add remote repository support using "git archive --remote=URI"

my $vcstype;
die "Only one of --local, --github, or --cvs may be specified.\n" if (($localdir && $github) || ($localdir && $cvs) || ($github && $cvs));
$vcstype = 'github' if !($localdir || $cvs);
$vcstype = 'local' if $localdir;
$vcstype = 'CVS' if $cvs;

#print "Running in $vcstype mode\n";

my $module = shift;
my $version = shift;
my $tmpdir = shift || "/tmp";
my $tag = shift;

#my $gitroot='git@github.com:fink/';
my $github_url="https://codeload.github.com/fink/$module/legacy.tar.gz";
my $cvsroot=':pserver:anonymous@fink.cvs.sourceforge.net:/cvsroot/fink';
my $distribution = "10.7";  #default value



# Bail out if all of the mandatory parameters aren't set
&print_usage_and_exit() if !($module && $version);

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

system("mkdir -p $tmpdir");
#cd $tmpdir
umask 022;

if (-d "$tmpdir/$fullname") {
	print "There is a left-over directory in $tmpdir.\n";
	print "Remove $fullname, then try again.\n";
	exit 1;
}

### grab code from version control

print "Exporting module $module, tag $tag from $vcstype:\n";

	# TODO: Make this more robust, e.g. first check that we are in a proper checkout/clone of the fink repository,
	# and if not, generate a more meaningful error.
	# TODO: verify that the "git" is available in the first place


if ($vcstype eq 'github') {
	system("umask 022; curl -L -f $github_url/$tag -o $tmpdir/$tag.tar.gz");

	if ($? or not -f "$tmpdir/$tag.tar.gz") {
		print "github download failed, could not retrieve remote data!\n";
		exit 1;
	}

} elsif ($vcstype eq 'local') {

	system("cd $localdir; umask 022; git archive --format=tar.gz --prefix=$fullname/ -o $tmpdir/$tag.tar.gz $tag");

	if ($? or not -f "$tmpdir/$tag.tar.gz") {
		print "Could not generate $tag.tar.gz!\n";
		exit 1;
	}

} elsif ($vcstype eq 'CVS') {

	# Original command using CVS:
	system('umask 022; cd $tmpdir; cvs -d "$cvsroot" export -r "$tag" -d $fullname $module');

	if (not -d "$tmpdir/$fullname") {
		print "CVS export failed, directory $fullname doesn't exist!\n";
		exit 1;
	}
	### remove any .cvsignore files
	`find $tmpdir/$fullname -name .cvsignore -exec rm {} \\;`;
	
	system("gzip $tmpdir/$fullname");

} else {


	print "unknown version control system '$vcstype'!\n";
	exit 1;
}
	# TODO: Add a mode to allow specifying a "remote" repository
	# via the git archive --remote option


my $taropts = "-xvf $tmpdir/$tag.tar.gz -C $tmpdir/$fullname --strip-components 1";

	`mkdir -p $tmpdir/$fullname && /usr/bin/tar $taropts`;

	if (not -d "$tmpdir/$fullname") {
		print "Export failed, directory $fullname doesn't exist!\n";
		exit 1;
	}

	### remove any .gitignore files
	# TODO: Really? There is only one, and it is harmless
	`find $tmpdir/$fullname -name .gitignore -exec rm {} \\;`;

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

#Refreshed coda with current SF.net mirrors as of 14 April 2014
my $coda = <<CODA;
CustomMirror: <<
Primary: http://downloads.sourceforge.net
afr-KE: http://liquidtelecom.dl.sourceforge.net/sourceforge
afr-ZA: http://tenet.dl.sourceforge.net/sourceforge
asi-JP: http://jaist.dl.sourceforge.net/sourceforge
asi-KZ: http://kaz.dl.sourceforge.net/sourceforge
asi-SG: http://softlayer-sng.dl.sourceforge.net/sourceforge
asi-TW: http://nchc.dl.sourceforge.net/sourceforge
asi-TW: http://ncu.dl.sourceforge.net/sourceforge
aus-AU: http://aarnet.dl.sourceforge.net/sourceforge
aus-AU: http://internode.dl.sourceforge.net/sourceforge
aus-AU: http://waia.dl.sourceforge.net/sourceforge
eur-CH: http://switch.dl.sourceforge.net/sourceforge
eur-CZ: http://cznic.dl.sourceforge.net/sourceforge
eur-CZ: http://ignum.dl.sourceforge.net/sourceforge
eur-DE: http://netcologne.dl.sourceforge.net/sourceforge
eur-DE: http://optimate.dl.sourceforge.net/sourceforge
eur-DE: http://skylink.dl.sourceforge.net/sourceforge
eur-FR: http://freefr.dl.sourceforge.net/sourceforge
eur-IE: http://heanet.dl.sourceforge.net/sourceforge
eur-IT: http://garr.dl.sourceforge.net/sourceforge
eur-RU: http://citylan.dl.sourceforge.net/sourceforge
eur-SE: http://sunet.dl.sourceforge.net/sourceforge
eur-UK: http://kent.dl.sourceforge.net/sourceforge
eur-UK: http://vorboss.dl.sourceforge.net/sourceforge
nam-CA: http://iweb.dl.sourceforge.net/sourceforge
nam-US: http://colocrossing.dl.sourceforge.net/sourceforge
nam-US: http://downloads.sourceforge.net
nam-US: http://softlayer-ams.dl.sourceforge.net/sourceforge
nam-US: http://softlayer-dal.dl.sourceforge.net/sourceforge
nam-US: http://superb-dca2.dl.sourceforge.net/sourceforge
nam-US: http://tcpdiag.dl.sourceforge.net/sourceforge
sam-BR: http://ufpr.dl.sourceforge.net/sourceforge
<<
CODA

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
