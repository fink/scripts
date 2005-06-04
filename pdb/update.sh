#!/bin/sh

echo "Updating CVS..."
cvs -q update -dP
cd Fink
cvs -q update -dP
cd ..

echo "Fixing permissions"
chgrp -R fink .
chmod -f -R g+w,a+r .
chmod o-rwx db.inc.pl
