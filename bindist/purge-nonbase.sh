#!/bin/sh

dpkg --get-selections | \
	grep -E '[[:space:]]install$' | \
	grep -v '^apt[[:space:]]' | \
	grep -v '^apt-shlibs[[:space:]]' | \
	grep -v '^base-files[[:space:]]' | \
	grep -v '^bzip2[[:space:]]' | \
	grep -v '^bzip2-shlibs[[:space:]]' | \
	grep -v '^cctools-extra[[:space:]]' | \
	grep -v '^debianutils[[:space:]]' | \
	grep -v '^dpkg[[:space:]]' | \
	grep -v '^fink[[:space:]]' | \
	grep -v '^fink-prebinding[[:space:]]' | \
	grep -v '^gettext[[:space:]]' | \
	grep -v '^gettext-bin[[:space:]]' | \
	grep -v '^gzip[[:space:]]' | \
	grep -v '^libiconv[[:space:]]' | \
	grep -v '^libiconv-bin[[:space:]]' | \
	grep -v '^ncurses[[:space:]]' | \
	grep -v '^ncurses-shlibs[[:space:]]' | \
	grep -v '^storable-pm[[:space:]]' | \
	grep -v '^storable-pm560[[:space:]]' | \
	grep -v '^tar[[:space:]]' | \
	grep -v '^unzip[[:space:]]' | \
	awk '{ print $1 }' | \
	xargs sudo dpkg --purge

