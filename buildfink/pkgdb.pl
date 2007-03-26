#!/usr/bin/perl

use strict;
use warnings;
use lib "/Volumes/SandBox/fink/sw/lib/perl5";
use lib "/Volumes/SandBox/fink/sw/lib/perl5/darwin";
use DBI;
use CGI qw(:standard param);
use JSON;

print "Status: 200 OK\n";
our $dbh = DBI->connect("dbi:SQLite:dbname=pkgdb.db", "", "", {
    RaiseError => 1,
    AutoCommit => 0
});

if(param() and param('op')) {
    my $op = param('op');

    print "Content-type: text/plain\n\n";
    if($op eq "pkgls") {
	my $pkg = param('pkg');
	my $sth = $dbh->prepare(
	    "SELECT fullpath AS 'path',
                    size, posix_user, posix_group, flags
             FROM file_versions LEFT OUTER JOIN packages
             ON file_versions.package_id = packages.package_id
             WHERE package_name=?
             ORDER BY is_directory DESC, fullpath ASC"
	);
	$sth->execute($pkg);
	print objToJson($sth->fetchall_arrayref({}));
    } elsif($op eq "ls") {
	my $dir_id = param('dir_id');

	my $sth = $dbh->prepare(
	    "SELECT file_paths.file_id AS 'file_id', file_name, 
                    is_directory, package_name
             FROM file_paths LEFT OUTER JOIN file_versions ON
                    file_paths.file_id = file_versions.file_id
             LEFT OUTER JOIN packages ON
                    packages.package_id = file_versions.package_id
             WHERE parent_id = ?"
	);
	$sth->execute($dir_id);

	my %rethash;
	foreach my $filever (@{$sth->fetchall_arrayref({})}) {
	    my $fname = $filever->{file_name};
	    $fname .= "/" if $filever->{is_directory};
	    $rethash{$fname} ||= {
		file_id => $filever->{file_id},
		name => $fname,
		is_directory => $filever->{is_directory},
		packages => []
            };
	    my $file = $rethash{$fname};
	    $file->{is_directory} = $filever->{is_directory};
	    push @{$file->{packages}}, $filever->{package_name};
	}

	@{$_->{packages}} = sort @{$_->{packages}} foreach values %rethash;
	print objToJson([map {
	    $rethash{$_}
        } sort {
	    $rethash{$b}->{is_directory} <=> $rethash{$a}->{is_directory}
	        or
	    $a cmp $b
	} keys %rethash]);
    }

    exit;
}

print "Content-type: text/html\n\n";

my @packages = @{$dbh->selectcol_arrayref("SELECT package_name FROM packages ORDER BY package_name ASC")};

print <<EOF;
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN" "DTD/xhtml1-strict.dtd">
<html>
<head>
    <title>Fink File Database</title>
    <link rel="stylesheet" type="text/css" href="pkgdb.css" />
    <script type="text/javascript" src="jquery-latest.pack.js" />
    <script type="text/javascript" src="pkgdb.js" />
</head>
<body>
<h1>Fink Package Database</h1>
<h2>Filesystem</h2>
<ul id="filesystem"><li class="directory"><a href="#" id="0">/sw</a></li></ul>
<h2>Packages</h2>
<ul id="packages">
@{[join("\n", map { "<li class=\"package\"><a href=\"#\">$_</a></li>" } @packages)]}
</ul>
</body>
</html>
EOF
