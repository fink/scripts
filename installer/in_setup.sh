#!/bin/sh
sed -e "s+BASEDIR+$IN_BASEDIR+g" -e "s+VERSION+$IN_VERSION+g" < fink.pmsp.in > fink-$IN_VERSION.pmsp