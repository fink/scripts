#!/bin/sh -e
#
# dist-full.sh - make release tarballs for a distribution release
#
# Fink - a package manager that downloads source and installs it
# Copyright (c) 2001 Christoph Pfisterer
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

### configuration

cvsroot=':pserver:anonymous@cvs.sourceforge.net:/cvsroot/fink'

### init

if [ $# -lt 2 ]; then
  echo "Usage: $0 <dist-version> <fink-version> <distribution> [<temporary-directory>]"
  exit 1
fi

dversion=$1
fversion=$2
distribution=$3
tmpdir=${4:-/tmp}
ptag=release_`echo $dversion | sed 's/\./_/g'`
ftag=release_`echo $fversion | sed 's/\./_/g'`

fullname="fink-$dversion-full"

echo "packaging full release $dversion, CVS tag $ptag"
echo "using package manager $fversion, CVS tag $ftag"
echo "and restricting files to the $distribution distribution"

### setup temp directory

mkdir -p $tmpdir
cd $tmpdir
umask 022

if [ -d $fullname -o -d pkginfo ]; then
  echo "There are left-over directories in $tmpdir."
  echo "Remove $fullname and/or pkginfo, then try again."
  exit 1
fi

### check code out from CVS

echo "Exporting module fink, tag $ftag from CVS:"
cvs -d "$cvsroot" export -r "$ftag" -d $fullname fink
if [ ! -d $fullname ]; then
  echo "CVS export failed, directory $fullname doesn't exist!"
  exit 1
fi

echo "Exporting module dists/$distribution, tag $ptag from CVS:"
cvs -d "$cvsroot" export -r "$ptag" -d pkginfo "dists/$distribution"
if [ ! -d pkginfo ]; then
  echo "CVS export failed, directory pkginfo doesn't exist!"
  exit 1
fi

### remove any .cvsignore files

find $fullname -name .cvsignore -exec rm {} \;
find pkginfo -name .cvsignore -exec rm {} \;

### versioning

echo $fversion >$fullname/VERSION
echo $dversion >pkginfo/VERSION
if [ -f pkginfo/stamp-cvs-live ]; then
  rm -f pkginfo/stamp-cvs-live
  touch pkginfo/stamp-rel-$dversion
fi

### roll the tarball

mv pkginfo $fullname/

echo "Creating tarball $fullname.tar:"
rm -f $fullname.tar $fullname.tar.gz
gnutar -cvf $fullname.tar $fullname
echo "Compressing tarball $fullname.tar.gz..."
gzip -9 $fullname.tar

if [ ! -f $fullname.tar.gz ]; then
  echo "Packaging failed, $fullname.tar.gz doesn't exist!"
  exit 1
fi

### finish up

echo "Done:"
ls -l *.tar.gz

exit 0
