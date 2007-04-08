package FDBWebsite;

use strict;
use warnings;
use FinkFDB;
use Apache2::RequestRec ();
use Apache2::RequestIO ();
use Apache2::Const -compile => qw(OK);
use JSON;
our %FDBParams;

sub handler {
  my($r) = @_;

  die "Please configure \%FDBWebsite::FDBParams in the Apache configuration!\n" unless %FDBParams;
  my $FDB = FinkFDB->new(%FDBParams);
  $FDB->connect();

  my(undef, $op, $param) = split(m!/!, $r->path_info());
  if ($op) {
    $r->content_type('text/plain');
    if ($op eq "package") {
      $r->print(objToJson([$FDB->getPackageFiles($param)]));
    } elsif ($op eq "ls") {
      # Group by file name, but include a list of packages.
      # This does the right thing because the SQL is already returning sorted results.
      my @ret;
      my $last;
      foreach my $file ($FDB->getDirectoryFiles($param)) {
	if(!$last or
	   $last->{file_id} != $file->{file_id} or
	   $last->{is_directory} != $file->{is_directory}
	  ) {
	  $last = {
		   file_name => $file->{file_name},
		   is_directory => $file->{is_directory},
		   file_id => $file->{file_id},
		   packages => []
		   };
	  $last->{file_name} .= "/" if $file->{is_directory};
	  push @ret, $last;
	}

	push @{$last->{packages}}, $file->{package_name};
      }

      $r->print(objToJson(\@ret));
    }
  } else {
    $r->content_type('text/html');
    my @packages = $FDB->getPackages();

    $r->print(<<EOF);
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN" "DTD/xhtml1-strict.dtd">
<html>
<head>
    <title>Fink File Database</title>
    <link rel="stylesheet" type="text/css" href="fdb.css" />
    <script type="text/javascript" src="jquery-latest.pack.js" />
    <script type="text/javascript" src="fdb.js" />
</head>
<body>
<h1>Fink File Database</h1>
<h2>Filesystem</h2>
<ul id="filesystem"><li class="tree-open"><a href="javascript:" id="root" file_id="0">/sw</a></li></ul>
<h2>Packages</h2>
<ul id="packages">
@{[join("\n", map { sprintf(
   '<li class="tree-closed"><a href="javascript:" package_id="%s">%s</a></li>',
   $_->{package_id},
   $_->{package_name})
} @packages)]}
  </ul>
  </body>
  </html>
EOF
  }

  $FDB->disconnect();
  return Apache2::Const::OK;
}

1;
