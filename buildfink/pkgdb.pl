#!/usr/bin/perl

use strict;
use warnings;
use Storable;
use CGI qw(:standard param);
use JSON;

print "Status: 200 OK\n";
our $data = retrieve("pkgdb.db");

if(param() and param('op')) {
    my $op = param('op');

    print "Content-type: text/plain\n\n";
    if($op eq "pkgls") {
	my $pkg = param('pkg');
	my $pkgfiles = $data->{pkgfiles}->{$pkg};
	print objToJson([map {
	    my @pathbits;
	    my $root = $_->{".."};
	    while($root) {
		unshift @pathbits, $root->{"."};
		$root = $root->{".."};
	    }
	    $_->{path} = join("/", @pathbits);

	    delete $_->{".."};
	    delete $_->{"."};
	    $_;
        } @$pkgfiles]);
    } elsif($op eq "ls") {
	my $path = param('path');
	$path =~ s!^%p/?!!;

	my $root = $data->{finkfiles};
	foreach my $pathbit(split(m!/!, $path)) {
	    $root = $root->{$pathbit};
	}

	my @dirs;
	my @files;
	foreach my $name(sort keys %$root) {
	    next if $name eq "." or $name eq ".." or $name eq "/files/";

	    my $obj = $root->{$name};
	    delete $obj->{".."};
	    delete $obj->{"."};

	    push @dirs, $name if grep {$_ ne "/files/"} keys %$obj;
	    push @files, $name if $obj->{"/files/"};
	}

	print objToJson({dirs => \@dirs, files => \@files});
    }

    exit;
}

print "Content-type: text/html\n\n";

my @packages = sort keys %{$data->{pkgfiles}};

print <<EOF;
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN" "DTD/xhtml1-strict.dtd">
<html>
<head>
    <title>Fink Package Database</title>
    <link rel="stylesheet" type="text/css" href="pkgdb.css" />
    <script type="text/javascript" src="jquery-latest.pack.js" />
    <script type="text/javascript" src="pkgdb.js" />
</head>
<body>
<h1>Fink Package Database</h1>
<h2>Filesystem</h2>
<ul id="filesystem"><li class="directory"><a href="#" id="%p">/sw</a></li></ul>
<h2>Packages</h2>
<ul id="packages">
@{[join("\n", map { "<li class=\"package\"><a href=\"#\">$_</a></li>" } @packages)]}
</ul>
</body>
</html>
EOF
