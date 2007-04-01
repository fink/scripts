package FDBWebsite;

use strict;
use warnings;
use FindBin qw($Bin);
use lib "$Bin/../lib";
use FinkFDB;
use Apache2::RequestRec ();
use CGI qw(:standard param);
use JSON;
our %FDBParams;

sub handler {
  my($r) = @_;

  die "Please configure \%FDBWebsite::FDBParams in the Apache configuration!\n" unless %FDBParams;
  my $FDB = FinkFDB->new(%FDBParams);

  my($op, $param) = split(m!/!, $r->path_info());
  if ($op) {
    $r->content_type('text/plain');
    if ($op eq "package") {
      $r->print(objToJson($FDB->getPackageFiles($param)));
    } elsif ($op eq "ls") {
      $r->print(objToJson(map {
	$_->{file_name} .= "/" if $_->{is_directory};
	$_;
      } $FDB->getDirectoryFiles($param)));
    }
  } else {
    $r->content_type('text/html');
    my $packages = $FDB->getPackages();

    $r->print(<<EOF);
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN" "DTD/xhtml1-strict.dtd">
<html>
<head>
    <title>Fink File Database</title>
    <link rel="stylesheet" type="text/css" href="pkgdb.css" />
    <script type="text/javascript" src="jquery-latest.pack.js" />
    <script type="text/javascript" src="pkgdb.js" />
</head>
<body>
<h1>Fink File Database</h1>
<h2>Filesystem</h2>
<ul id="filesystem"><li class="directory"><a href="#" file_id="0">/sw</a></li></ul>
<h2>Packages</h2>
<ul id="packages">
@{[join("\n", map { sprintf(
   '<li class="package"><a href="#" package_id="%s">%s</a></li>',
   $_->{package_id},
   $_->{package_name})
} @packages)]}
  </ul>
  </body>
  </html>
EOF
  }
}

1;
