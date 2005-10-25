#!/bin/sh

echo "Updating CVS..."
cvs -q update -dP
cd basepath
cvs -q update -dP
cd perlmod/Fink
rm -f FinkVersion.pm
sed "s|@VERSION@|`cat ../../VERSION`|" < FinkVersion.pm.in > FinkVersion.pm
cd ../../..

echo "Fixing permissions"
chgrp -R fink .
chmod -f -R g+w,a+r .
chmod o-rwx db.inc.pl
