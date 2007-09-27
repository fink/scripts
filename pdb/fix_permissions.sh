#!/bin/sh
set -e

echo "Fixing permissions..."
chgrp -R fink_web .
chmod -f -R g+w,a+r .
if [ -f .finkdbi ]; then
  chmod -f go-rw .finkdbi
fi
if [ -f finksql ]; then
  chmod -f go-rw finksql
  chmod u+x finksql
fi

exit 0
