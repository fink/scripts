#!/bin/sh

echo "Updating CVS..."
cvs -q update -dP
cd Fink
cvs -q update -dP
cd ..

echo "Fixing permissions"
chmod -f -R g+w,a+r .
chgrp -R fink .
