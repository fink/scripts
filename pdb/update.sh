#!/bin/sh
set -e

echo "Updating CVS..."
cvs -q update -dPl
echo "Updating CVS (basepath)..."
cd basepath
cvs -q update -dP
cd ..

./fix_permissions.sh

echo "Creating fink itself..."
cd basepath
./setup.sh $PWD/basepath
cd ..
