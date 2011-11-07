#!/bin/bash

# sanity check: presence of target directory
if [[ ! -d $IN_BASEDIR ]]; then
    echo "IN_BASEDIR '$IN_BASEDIR' does not exist!"
    exit 1
fi

# sanity check: if FINK_ROOT not set, give it a default value
if [[ ! $FINK_ROOT ]]; then
	FINK_ROOT=/sw
fi
echo "FINK_ROOT=$FINK_ROOT"

# sanity check: presence of contents directory with Fink tree
if [[ ! -d $IN_BASEDIR/contents$FINK_ROOT ]]; then
	echo "'$IN_BASEDIR/contents$FINK_ROOT' does not exist!"
	echo "Your Fink tree should have been copied here before"
	echo "running this script."
	exit 1
fi

# sanity check: bindist version number format is #.#.#
shopt -q extglob
save_shopt=$?
shopt -qs extglob
echo "BINDIST_VERSION=$BINDIST_VERSION"
if [[ "$BINDIST_VERSION" != +([0-9]).+([0-9]).+([0-9]) ]]; then
    echo "BINDIST_VERSION '$BINDIST_VERSION' does not match (majornum).(minornum).(teenynum)"
    exit 1
fi
if [[ $save_shopt -ne 0 ]]; then
  shopt -qu extglob
fi

# sanity check: OSX version number format is #.#
shopt -q extglob
save_shopt=$?
shopt -qs extglob
echo "OSX_VERSION=$OSX_VERSION"
if [[ "$OSX_VERSION" != +([0-9]).+([0-9]) ]]; then
    echo "OSX_VERSION '$OSX_VERSION' does not match (majornum).(minornum)"
    exit 1
fi
if [[ $save_shopt -ne 0 ]]; then
  shopt -qu extglob
fi

# sanity check: ARCH is set correctly (and if so, we set some other stuff)
case $ARCH in
PowerPC)
 echo "ARCH=PowerPC"
 CPU_NAME="Power Macintosh"
 ;;
Intel)
 echo "ARCH=Intel"
 CPU_NAME="i386"
 ;;
x86_64)
 echo "ARCH=x86_64"
 CPU_NAME="x86_64"
 ;;
*)
 echo "Error: you must set the environment variable ARCH to either PowerPC,  Intel or x86_64."
 exit 1
 ;;
esac

IN_VERSION=$BINDIST_VERSION-$ARCH;

RESDIR=$IN_BASEDIR/resources-$IN_VERSION;
DMGDIR=$IN_BASEDIR/dmg-$IN_VERSION;
CONDIR=$IN_BASEDIR/contents-$IN_VERSION;

if [[ -e $IN_BASEDIR/Fink-$IN_VERSION-Installer.dmg ]]; then
	echo ""
	echo "\"Fink-$IN_VERSION-Installer.dmg\" already exists in the installer directory! Quitting so you can move/delete it."
	exit 1
fi

echo "basedir: $IN_BASEDIR";
echo "version: $IN_VERSION";
rm -rf $RESDIR
rm -rf $DMGDIR
rm -rf $CONDIR

chmod a+x $IN_BASEDIR/mkdmg.pl 
chmod a+x $IN_BASEDIR/resources/InstallationCheck
chmod a+x $IN_BASEDIR/resources/postflight
chmod a+x $IN_BASEDIR/resources/VolumeCheck

cp -R $IN_BASEDIR/resources $RESDIR
/Developer/Tools/CpMac -r $IN_BASEDIR/dmg $DMGDIR
cp $IN_BASEDIR/resources/ReadMe.rtf $DMGDIR/Fink\ ReadMe.rtf
cp $IN_BASEDIR/resources/License.rtf $DMGDIR
cp -Rp $IN_BASEDIR/contents $CONDIR
# Don't chown -R $CONDIR because we need to keep ownerships intact
# for some files (primarily in FINK_ROOT/var) throughout the hierarchy.
#chown -R root:admin $CONDIR
chmod 1755 $CONDIR
rm -Rf $CONDIR/CVS
rm -f $CONDIR/.cvsignore
rm -Rf $RESDIR/CVS
rm -Rf $RESDIR/*/CVS
rm -Rf $DMGDIR/CVS
rm -f $DMGDIR/.cvsignore
rm -Rf $DMGDIR/*/CVS
rm -Rf $DMGDIR/*/*/CVS

# Create symlinks for documentation
ln -s doc/doc.en.html $DMGDIR/Documentation.html
ln -s faq/faq.en.html $DMGDIR/FAQ.html

# Put the correct pathsetup script into pathsetup.app
mkdir -p $DMGDIR/pathsetup.app/Contents/MacOS
cp $IN_BASEDIR/contents${FINK_ROOT}/bin/pathsetup.sh $DMGDIR/pathsetup.app/Contents/MacOS/pathsetup
chmod a+x $DMGDIR/pathsetup.app/Contents/MacOS/pathsetup

# permissions for pathsetup.app
chmod 555 $DMGDIR/pathsetup.app
chmod 555 $DMGDIR/pathsetup.app/Contents/MacOS
chmod 555 $DMGDIR/pathsetup.app/Contents/Resources

# Subsitute the Fink root for FINK_ROOT where appropriate
perl -pi -e "s|FINK_ROOT|$FINK_ROOT|g" $RESDIR/InstallationCheck $RESDIR/VolumeCheck $RESDIR/postflight

# prepare InstallationCheck for OS X version and hardware
perl -pi -e "s/OSX_VERSION/$OSX_VERSION/g; s/CPU_NAME/$CPU_NAME/g" $RESDIR/InstallationCheck

# Substitute the version for BINDIST_VERSION where appropriate
perl -pi -e "s/OSX_VERSION/$OSX_VERSION/g; s/BINDIST_VERSION/$BINDIST_VERSION/g; s/ARCH/$ARCH/g; s/IN_VERSION/$IN_VERSION/g" $RESDIR/ReadMe.rtf $RESDIR/Welcome.rtf $RESDIR/*.lproj/Description.plist $DMGDIR/Fink\ ReadMe.rtf

# Prepare Info.plist for this specific .pkg
sed -e "s|@IN_VERSION@|$IN_VERSION|g" < $IN_BASEDIR/Info.plist.in > $IN_BASEDIR/Info.plist

# Add "missing" language directories to work around a bug in Installer.app
for lang in Dutch French German Italian Japanese Spanish da fi ko no pt sv zh_CN zh_TW; do
  if test ! -d $RESDIR/${lang}.lproj ; then
    cp -r $RESDIR/English.lproj $RESDIR/${lang}.lproj
    rm -rf $RESDIR/${lang}.lproj/CVS
  fi
done

echo "running PackageMaker...";
#/Developer/Applications/Utilities/PackageMaker.app/Contents/MacOS/PackageMaker -build -p "$DMGDIR/Fink $IN_VERSION Installer for $OSX_VERSION.pkg" -f $CONDIR -r $RESDIR -i $IN_BASEDIR/Info.plist -d $RESDIR/English.lproj/Description.plist -v

`find $DMGDIR -name 'CVS' -type d -exec rm -rf {} \; 2>> /dev/null`
`find $DMGDIR -name '.DS_Store' -type d -exec rm -rf {} \; 2>> /dev/null`

# Make the .pkg after clearing out unwanted files.
/Developer/usr/bin/packagemaker \
--root $CONDIR \
--info Info.plist \
--out "$DMGDIR/Fink $IN_VERSION Installer for $OSX_VERSION.pkg" \
--title "Fink for OS X $OSX_VERSION" \
--resources $RESDIR \
--target 10.4 \
--no-recommend \
--no-relocate \
--root-volume-only \
-v

## Why change the permissions for all dirs inside the dmg-to-be?
chmod -R a+rX $DMGDIR
#$IN_BASEDIR/mkdmg.pl -v "Fink-$IN_VERSION-Installer.dmg" $DMGDIR/*

echo "Creating disk image..."
hdiutil create \
-srcfolder $DMGDIR \
-fs HFS+ \
-volname "Fink $IN_VERSION Installer" \
-format UDBZ "Fink-$IN_VERSION-Installer.dmg"

echo ""
echo "The disk image has been created and is ready for distribution."
