#!/bin/sh
RESDIR=$IN_BASEDIR/resources-$IN_VERSION;
DMGDIR=$IN_BASEDIR/dmg-$IN_VERSION;

echo "basedir: $IN_BASEDIR version: $IN_VERSION";
rm -rf $RESDIR
rm -rf $DMGDIR
chown -R root:admin $IN_BASEDIR/contents 
chmod 1755 $IN_BASEDIR/contents
chmod a+x $IN_BASEDIR/mkdmg.pl 
chmod a+x $IN_BASEDIR/resources/InstallationCheck
chmod a+x $IN_BASEDIR/resources/postflight
chmod a+x $IN_BASEDIR/resources/VolumeCheck
cp -R $IN_BASEDIR/resources $RESDIR
cp -R $IN_BASEDIR/dmg $DMGDIR
rm -Rf $IN_BASEDIR/contents/CVS
rm -f $IN_BASEDIR/contents/.cvsignore
rm -Rf $RESDIR/CVS
rm -Rf $RESDIR/*/CVS
rm -Rf $DMGDIR/CVS
rm -f $DMGDIR/.cvsignore
rm -Rf $DMGDIR/*/CVS
rm -Rf $DMGDIR/*/*/CVS


# Substitute the version for IN_VERSION where appropriate
perl -pi -e "s/IN_VERSION/$IN_VERSION/g" $RESDIR/ReadMe.rtf $RESDIR/Welcome.rtf $RESDIR/*.lproj/Description.plist $DMGDIR/Fink\ ReadMe.rtf

# Add "missing" language directories to work around a bug in Installer.app
for lang in Dutch French German Italian Japanese Spanish da fi ko no pt sv zh_CN zh_TW; do
  if test ! -d ${lang}.lproj ; then
    cp -r $RESDIR/English.lproj $RESDIR/${lang}.lproj
    rm -rf $RESDIR/${lang}.lproj/CVS
  fi
done

echo "running PackageMaker...";
/Developer/Applications/PackageMaker.app/Contents/MacOS/PackageMaker -build -p "$DMGDIR/Fink $IN_VERSION Installer.pkg" -f $IN_BASEDIR/contents -r $RESDIR -i $IN_BASEDIR/fink.info -d $RESDIR/English.lproj/Description.plist
perl -pi -e 's#</dict>#<key>IFPkgFlagAuthorizationAction</key>\n<string>RootAuthorization</string>\n</dict>#g' "$DMGDIR/Fink $IN_VERSION Installer.pkg/Contents/Info.plist"
`find $DMGDIR -name 'CVS' -type d -exec rm -rf {} \; 2>> /dev/null`

chmod -R a+rX $DMGDIR
$IN_BASEDIR/mkdmg.pl -v "Fink $IN_VERSION Installer.dmg" $DMGDIR/*
# "$DMGDIR/Fink $IN_VERSION Installer.pkg" "$DMGDIR/Fink ReadMe.rtf"  "$DMGDIR/Fink Web Site.url" "$DMGDIR/License.rtf" "$DMGDIR/users-guide.html"
mv "Fink $IN_VERSION Installer.dmg" Fink-$IN_VERSION-Installer.dmg