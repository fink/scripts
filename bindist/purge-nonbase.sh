#!/bin/sh

dpkg --get-selections | \
	grep -E '[[:space:]]install$' | \
	grep -v '^apt[[:space:]]' | \
	grep -v '^apt-shlibs[[:space:]]' | \
	grep -v '^base-files[[:space:]]' | \
	grep -v '^bzip2[[:space:]]' | \
	grep -v '^debianutils[[:space:]]' | \
	grep -v '^dpkg[[:space:]]' | \
	grep -v '^fink[[:space:]]' | \
	grep -v '^gettext[[:space:]]' | \
	grep -v '^gzip[[:space:]]' | \
	grep -v '^libiconv[[:space:]]' | \
	grep -v '^ncurses[[:space:]]' | \
	grep -v '^storable-pm[[:space:]]' | \
	grep -v '^tar[[:space:]]' | \
	grep -v '^xml-rss-pm[[:space:]]' | \
	grep -v '^compress-zlib-pm[[:space:]]' | \
	grep -v '^digest-md5-pm[[:space:]]' | \
	grep -v '^html-parser-pm[[:space:]]' | \
	grep -v '^html-tagset-pm[[:space:]]' | \
	grep -v '^libnet-pm[[:space:]]' | \
	grep -v '^libwww-pm[[:space:]]' | \
	grep -v '^mime-base64-pm[[:space:]]' | \
	grep -v '^uri-pm[[:space:]]' | \
	grep -v '^xml-parser-pm[[:space:]]' | \
	awk '{ print $1 }' | \
	xargs sudo dpkg --purge

