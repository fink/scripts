#!/bin/sh
RESDIR=$IN_BASEDIR/resources-$IN_VERSION;
DMGDIR=$IN_BASEDIR/dmg-$IN_VERSION;
CONDIR=$IN_BASEDIR/contents-$IN_VERSION;

echo "basedir: $IN_BASEDIR version: $IN_VERSION";
rm -rf $RESDIR
rm -rf $DMGDIR
rm -rf $CONDIR

chmod a+x $IN_BASEDIR/mkdmg.pl 
chmod a+x $IN_BASEDIR/resources/InstallationCheck
chmod a+x $IN_BASEDIR/resources/postflight
chmod a+x $IN_BASEDIR/resources/VolumeCheck

cp -R $IN_BASEDIR/resources $RESDIR
/Developer/Tools/CpMac -r $IN_BASEDIR/dmg $DMGDIR
cp -R $IN_BASEDIR/contents $CONDIR
chown -R root:admin $CONDIR
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
cp contents/sw/bin/pathsetup.sh $DMGDIR/pathsetup.app/Contents/MacOS/pathsetup
chmod a+x $DMGDIR/pathsetup.app/Contents/MacOS/pathsetup

# permissions for pathsetup.app
chmod 555 $DMGDIR/pathsetup.app
chmod 555 $DMGDIR/pathsetup.app/Contents/MacOS
chmod 555 $DMGDIR/pathsetup.app/Contents/Resources

# Substitute the version for IN_VERSION where appropriate
perl -pi -e "s/IN_VERSION/$IN_VERSION/g" $RESDIR/ReadMe.rtf $RESDIR/Welcome.rtf $RESDIR/*.lproj/Description.plist $DMGDIR/Fink\ ReadMe.rtf

# Add "missing" language directories to work around a bug in Installer.app
for lang in Dutch French German Italian Japanese Spanish da fi ko no pt sv zh_CN zh_TW; do
  if test ! -d $RESDIR/${lang}.lproj ; then
    cp -r $RESDIR/English.lproj $RESDIR/${lang}.lproj
    rm -rf $RESDIR/${lang}.lproj/CVS
  fi
done

echo "running PackageMaker...";
/Developer/Applications/Utilities/PackageMaker.app/Contents/MacOS/PackageMaker -build -p "$DMGDIR/Fink $IN_VERSION Installer.pkg" -f $CONDIR -r $RESDIR -i $IN_BASEDIR/fink.info -d $RESDIR/English.lproj/Description.plist
perl -pi -e 's#</dict>#<key>IFPkgFlagAuthorizationAction</key>\n<string>RootAuthorization</string>\n</dict>#g' "$DMGDIR/Fink $IN_VERSION Installer.pkg/Contents/Info.plist"
`find $DMGDIR -name 'CVS' -type d -exec rm -rf {} \; 2>> /dev/null`

chmod -R a+rX $DMGDIR
$IN_BASEDIR/mkdmg.pl -v "Fink $IN_VERSION Installer.dmg" $DMGDIR/*
# "$DMGDIR/Fink $IN_VERSION Installer.pkg" "$DMGDIR/Fink ReadMe.rtf"  "$DMGDIR/Fink Web Site.url" "$DMGDIR/License.rtf" "$DMGDIR/users-guide.html"
mv "Fink $IN_VERSION Installer.dmg" Fink-$IN_VERSION-Installer.dmg
