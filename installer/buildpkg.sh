#!/bin/sh
RESDIR=$IN_BASEDIR/resources$IN_VERSION;
DMGDIR=$IN_BASEDIR/dmg$IN_VERSION;

echo "basedir: $IN_BASEDIR version: $IN_VERSION";
rm -rf $RESDIR
rm -rf $DMGDIR
chmod 1755 $IN_BASEDIR/contents
cp -r $IN_BASEDIR/resources $RESDIR
cp -r $IN_BASEDIR/dmg $DMGDIR
perl -pi -e "s/IN_VERSION/$IN_VERSION/g" $RESDIR/ReadMe.rtf $RESDIR/Welcome.rtf $RESDIR/English.lproj/Description.plist $DMGDIR/Fink\ ReadMe.rtf
echo "calling /Developer/Applications/PackageMaker.app/Contents/MacOS/PackageMaker -build -p \"$IN_BASEDIR/dmg/Fink $IN_VERSION Installer.pkg\" -f $IN_BASEDIR/contents -r $RESDIR -i $IN_BASEDIR/fink.info -d $RESDIR/English.lproj/Description.plist";

/Developer/Applications/PackageMaker.app/Contents/MacOS/PackageMaker -build -p "$DMGDIR/Fink $IN_VERSION Installer.pkg" -f $IN_BASEDIR/contents -r $RESDIR -i $IN_BASEDIR/fink.info -d $RESDIR/English.lproj/Description.plist
`find $DMGDIR/Fink\ $IN_VERSION\ Installer.pkg -name 'CVS' -type d -exec rm -rf {} \;`
