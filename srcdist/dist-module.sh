#!/bin/sh -e
#
# dist-module.sh - make release tarballs for one CVS module
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

### configuration

cvsroot=':pserver:anonymous@fink.cvs.sourceforge.net:/cvsroot/fink'

### init

if [ $# -lt 2 ]; then
  echo "Usage: $0 <module> <version-number> [<temporary-directory> [<tag>]]"
  exit 1
fi

module=$1
version=$2
tmpdir=${3:-/tmp}
tag=$4
if [ -z "$tag" ]; then
  tag=release_`echo $version | sed 's/\./_/g'`
fi
modulename=`echo $module | sed 's/\//-/g'`
fullname="$modulename-$version"

echo "packaging $module release $version, CVS tag $tag"

### setup temp directory

mkdir -p $tmpdir
cd $tmpdir
umask 022

if [ -d $fullname ]; then
  echo "There is a left-over directory in $tmpdir."
  echo "Remove $fullname, then try again."
  exit 1
fi

### check code out from CVS

echo "Exporting module $module, tag $tag from CVS:"
cvs -d "$cvsroot" export -r "$tag" -d $fullname $module
if [ ! -d $fullname ]; then
  echo "CVS export failed, directory $fullname doesn't exist!"
  exit 1
fi

### remove any .cvsignore files

find $fullname -name .cvsignore -exec rm {} \;

### versioning

if [ -f $fullname/VERSION ]; then
  echo $version >$fullname/VERSION
fi
if [ -f $fullname/stamp-cvs-live ]; then
  rm -f $fullname/stamp-cvs-live
  touch $fullname/stamp-rel-$version
fi

### roll the tarball

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

### create package description file

echo " "
echo "Creating package description file $modulename.info:"

md5=`/sbin/md5 -q $fullname.tar.gz`
/usr/bin/sed -e 's/\@VERSION\@/'$version'/' -e 's/\@REVISION\@/1/' -e 's/\@MD5\@/'$md5'/' -e 's,%n-%v.tar,mirror:custom:fink/%n-%v.tar.gz,' -e 's/NoSourceDirectory: true//' <$fullname/$modulename.info.in >$modulename.info

echo "CustomMirror: <<"  >> $modulename.info
echo " Primary: http://west.dl.sourceforge.net/sourceforge/" >> $modulename.info
echo " nam-US: http://us.dl.sourceforge.net/sourceforge/" >> $modulename.info
echo " eur: http://eu.dl.sourceforge.net/sourceforge/" >> $modulename.info
echo "<<" >> $modulename.info

echo "Done:"
ls -l *.info

exit 0
