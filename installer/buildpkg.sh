#!/bin/sh
RESDIR=$IN_BASEDIR/resources-$IN_VERSION;
DMGDIR=$IN_BASEDIR/dmg-$IN_VERSION;

echo "basedir: $IN_BASEDIR version: $IN_VERSION";
rm -rf $RESDIR
rm -rf $DMGDIR
chown -R root:admin $IN_BASEDIR/contents 
chmod 1755 $IN_BASEDIR/contents
chmod a+x $IN_BASEDIR/resources/InstallationCheck
chmod a+x $IN_BASEDIR/resources/postflight
chmod a+x $IN_BASEDIR/resources/VolumeCheck
cp -r $IN_BASEDIR/resources $RESDIR
cp -r $IN_BASEDIR/dmg $DMGDIR
perl -pi -e "s/IN_VERSION/$IN_VERSION/g" $RESDIR/ReadMe.rtf $RESDIR/Welcome.rtf $RESDIR/English.lproj/Description.plist $DMGDIR/Fink\ ReadMe.rtf
echo "calling /Developer/Applications/PackageMaker.app/Contents/MacOS/PackageMaker -build -p \"$IN_BASEDIR/dmg/Fink $IN_VERSION Installer.pkg\" -f $IN_BASEDIR/contents -r $RESDIR -i $IN_BASEDIR/fink.info -d $RESDIR/English.lproj/Description.plist";

/Developer/Applications/PackageMaker.app/Contents/MacOS/PackageMaker -build -p "$DMGDIR/Fink $IN_VERSION Installer.pkg" -f $IN_BASEDIR/contents -r $RESDIR -i $IN_BASEDIR/fink.info -d $RESDIR/English.lproj/Description.plist
perl -pi -e 's#</dict>#<key>IFPkgFlagAuthorizationAction</key>\n<string>RootAuthorization</string>\n</dict>#g' "$DMGDIR/Fink $IN_VERSION Installer.pkg/Contents/Info.plist"
`find $DMGDIR -name 'CVS' -type d -exec rm -rf {} \; 2>> /dev/null`

chmod -R a+rX $DMGDIR
