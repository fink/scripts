#!/usr/bin/perl

$| = 1;
require 5.006;  # perl 5.6.0 or newer required
use strict;

use Fink::Services qw(&read_config &filename &execute);
use Fink::Config;
use Fink::Package;
use Fink::PkgVersion;
use File::Find;
use Getopt::Std;

use vars qw(
	$BASEDIR
	$CONFIG
	$FINKDIR
	$RELEASE
	$VERSION
	$VOLNAME

	%PACKAGES
	%OPTIONS

	@BINDIRS
);

getopts('hf:v:', \%OPTIONS);

if ($OPTIONS{'h'}) {
	print <<END;
usage: $0 [-h] [-f <fink_root>] [-v <volume_name>]

       -h/--help    this help
  -f <fink_root>    the location of your Fink installation
                    (if it's not /sw)
-v <volume_name>    the name of the CD volume prefix
                    (default: FINKCD)

END
	exit 0;
}

{
	my @date  = localtime(time);
	$date[5] += 1900;
	$date[4]++;
	$VERSION  = `cat ${FINKDIR}/fink/VERSION`;
	$VERSION  =~ s/[\s\r\n]//gs;
	$VERSION .= sprintf('-%4d%2d%2d', $date[5], $date[4], $date[3]);
}

$FINKDIR = '/sw';
$VOLNAME = 'FINKCD';
$RELEASE = "fink-${VERSION}";
$BASEDIR = "dists/${RELEASE}";

$FINKDIR = $OPTIONS{'f'} if (exists $OPTIONS{'f'});
$VOLNAME = $OPTIONS{'v'} if (exists $OPTIONS{'v'});

$CONFIG  = &read_config($FINKDIR . '/etc/fink.conf');
Fink::Package->require_packages();

# first we find the list of binary packages
find( \&get_debpackages, $FINKDIR . '/fink' );

my ($cdnum, $dirname, $pkgspec, $pkgname, $po, $bindir, $binfile, $debfile, $linkpath, $i, $section, $tree, $stat);

$cdnum = 1;
$dirname = make_cd_image("${VOLNAME}${cdnum}") or die "can't make CD image for ${VOLNAME}${cdnum}\n";

# put the installer in the first CD
{
	my $file = get_installer();
	system("cp '/tmp/${file}' '${dirname}/'");
}

foreach $pkgspec (sort keys %PACKAGES) {

	VERSIONLOOP: for my $version (@{$PACKAGES{$pkgspec}->{versions}}) {

		$po = Fink::PkgVersion->match_package($pkgspec);
		if (not defined($po)) { print "ERROR: can't resolve \"$pkgspec\"\n"; next; }

		$pkgname = $po->get_fullname();
		$debfile = $po->find_debfile();
		$section = $po->get_section();
		$tree    = $po->get_tree();

		if (not defined($debfile)) { print "ERROR: no binary package for $pkgname\n"; next; }

		my @stat = stat($debfile);
		open(DF, "df ${dirname} |") or die "can't get disk usage on ${dirname}: $!\n";
		<DF>;
		my (undef, undef, undef, $usage) = split(/\s+/, <DF>);
		close(DF);
		if ($usage < $stat[12]) {
			$cdnum++;
			$dirname = make_cd_image("${VOLNAME}${cdnum}") or die "can't make CD image for ${VOLNAME}${cdnum}\n";
		}

		if ($section eq "crypto") {
			$bindir   = "${dirname}/${BASEDIR}/crypto/binary-darwin-powerpc";
		} else {
			$bindir   = "${dirname}/${BASEDIR}/main/binary-darwin-powerpc/${section}";
		}

		$binfile = $bindir."/".&filename($debfile);

		if (not -d $bindir) {
			&execute("mkdir -p $bindir");
		}
		if (-e $binfile) {
			unlink($binfile);
		}

		print "$debfile\n";
		system("cp $debfile $binfile");
	}
}

for my $index (1..$cdnum) {
	@BINDIRS = ();
	my $volname = uc($VOLNAME) . $index;
	find( \&get_cdbindirs, '/Volumes/' . $volname );

	for my $bindir (@BINDIRS) {
		chdir('/Volumes/' . $volname);
		$bindir =~ s#/Volumes/${volname}/?##;
		print "bindir = $bindir\n";
		system("dpkg-scanpackages '$bindir' /dev/null | gzip > '/Volumes/${volname}/${bindir}/Packages.gz'");
	}

	system("hdiutil unmount '/Volumes/${volname}'");
}

sub get_cdbindirs {
	return unless ($File::Find::name =~ m#binary-[^/]+$#);
	push(@BINDIRS, $File::Find::name);
}

sub get_debpackages {
	return unless ($File::Find::name =~ /\.deb$/);
	return if     ($File::Find::dir =~ m#${FINKDIR}/fink/debs#);
	return unless (-r $_);

	my $file = $File::Find::name;
	(my $dist) = $file =~ m#/*${FINKDIR}/+fink/+[^/]+/+([^/]+)/# or print "no dist match: $file\n";;
	$file =~ s/^.*binary-[^\/]+\///;

	my ($section);
	if ($file =~ /^(.+)\/([^\/]+)$/) {
		$section = $1;
		$file    = $2;
	} else {
		$section = 'unknown';
	}

	my ($package, $version, $arch) = split('_', $file);

	push(@{$PACKAGES{$package}->{versions}}, [ $version, $dist, $section, $file ]);
}

sub get_installer {
	my $installerfile;
	open(INSTALLER, "curl http://sourceforge.net/project/showfiles.php?group_id=17203 2>/dev/null |") or die "can't run curl: $!\n";
	while (<INSTALLER>) {
		if (m#href=.*\.sourceforge\.net/fink/(fink-[^\-]+-installer.dmg)#i) {
			$installerfile = $1 unless (defined $installerfile);
		}
	}
	close(INSTALLER);
	if (not defined $installerfile) {
		print "unable to find the fink installer on the download page\n";
		return;
	} else {
		if (! -f "/tmp/${installerfile}") {
			print "- downloading ${installerfile}... ";
			system("curl -C -o '/tmp/${installerfile}' 'http://us.dl.sf.net/fink/${installerfile}' >/dev/null 2>\&1") == 0 or die "failed";
			print "done.\n";
		}
		return $installerfile;
	}
}

sub get_key {
	my $key  = lc(shift);
	my $file = shift;
	my $return;

	open (GETKEY, $file) or die "can't read from $file: $!\n";
	while (<GETKEY>) {
		chomp;
		if ($_ =~ /^\s*${key}\s*:\s*(.*?)\s*$/i) {
			$return = $1;
			last;
		}
	}
	close (GETKEY);

	return $return;
}

sub make_cd_image {
	my $volume = uc(shift);
	my $name   = lc($volume);

	if (-f "/tmp/${name}.dmg") {
		print "warning: /tmp/${name}.dmg exists -- deleting files!\n";
		if (! -d "/Volumes/${volume}") {
			system("hdiutil mount '/tmp/${name}.dmg'");
		}
		system("rm -rf '/Volumes/${volume}/'*");
	} else {
		system("hdiutil create -fs 'HFS+' -volname '${volume}' -layout 'UNIVERSAL CD' -size 610m -ov /tmp/${name}");
		system("hdiutil mount /tmp/${name}.dmg");
	}

	if (-d "/Volumes/${volume}") {
		system("mkdir -p /Volumes/${volume}/${BASEDIR}");
		unlink("/Volumes/${volume}/dists/finkcd");
		symlink(${RELEASE}, "/Volumes/${volume}/dists/finkcd");

		for my $tree ('crypto', 'main') {
			system("mkdir -p /Volumes/${volume}/dists/finkcd/${tree}/binary-darwin-powerpc");
			open(RELEASEFILE, ">/Volumes/${volume}/dists/finkcd/${tree}/binary-darwin-powerpc/Release")
				or die "can't write to ${tree}/binary-darwin-powerpc/Release: $!\n";
			print RELEASEFILE "Archive: finkcd\n";
			print RELEASEFILE "Component: ${tree}\n";
			print RELEASEFILE "Origin: Fink\n";
			print RELEASEFILE "Label: Fink\n";
			print RELEASEFILE "Architecture: darwin-powerpc\n";
			close(RELEASEFILE);
		}

		return "/Volumes/${volume}";
	} else {
		return;
	}
}
