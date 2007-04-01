package FinkFDB::DBI;
use strict;
use warnings;
use DBI;
our @ISA = qw(FinkFDB);

our %dbqueries = (
		  add_package => "INSERT INTO packages(package_name) VALUES (?)",
		  add_file_path => "INSERT INTO file_paths(parent_id, file_name, fullpath) VALUES (?, ?, ?)",
		  add_file_version => <<EOF,
INSERT INTO file_versions(
    package_id,
    is_directory,
    fullpath,
    file_id,
    size,
    posix_user,
    posix_group,
    flags)
VALUES (?, ?, ?, ?, ?, ?, ?, ?)
EOF
		  get_package_id => "SELECT package_id FROM packages WHERE package_name = ?",
		  get_file_id => "SELECT file_id FROM file_paths WHERE fullpath = ?",
		  get_package_files => <<EOF,
SELECT fullpath AS 'path',
   size, posix_user, posix_group, flags
FROM file_versions LEFT OUTER JOIN packages
   ON file_versions.package_id = packages.package_id
WHERE package_name=?
ORDER BY is_directory DESC, fullpath ASC
EOF
		  get_directory_files => <<EOF,
SELECT file_name,
   size, posix_user, posix_group, flags,
   file_paths.file_id AS 'file_id',
   is_directory, package_name
FROM file_paths LEFT OUTER JOIN file_versions
   ON file_paths.file_id = file_versions.file_id
LEFT OUTER JOIN packages
   ON packages.package_id = file_versions.package_id
WHERE parent_id = ?
ORDER BY is_directory DESC, file_name ASC
EOF
		  get_packages => "SELECT package_name, package_id FROM packages ORDER BY package_name ASC",
		  );

sub new {
  my($pkg, %params) = @_;
  my $self = {};
  my $class = ref($pkg) || $pkg || __PACKAGE__;
  bless $self, $class;

  $self->{dbtype} = $params{dbtype} or die "Must specify dbtype for DBI store.\n";
  my $dbstr;
  my %dbattrs = (RaiseError => 1, AutoCommit => 0);
  if (lc($self->{dbtype}) eq "sqlite") {
    die "Must specify db for DBI SQLite.\n" unless $params{db};
    $dbstr = sprintf("dbi:SQLite:dbname=%s", $params{db});
  } else {
    $dbstr = sprintf("dbi:%s:%s", $self->{dbtype}, $params{db});
  }

  $self->{dbh} = DBI->connect($dbstr, $params{dbuser}, $params{dbpass}, \%dbattrs);
  $self->{queries} = {};

  return $self;
}

sub addPackage {
  my($self, $package) = @_;
  $self->execQuery("add_package", $package);
  $self->{dbh}->commit();
}

sub addPackageFiles {
  my($self, $package, $files) = @_;

  my $package_id = $self->selectOne("get_package_id", $package);
  if(!$package_id) {
    $self->addPackage($package);
    $package_id = $self->selectOne("get_package_id", $package) or
      die "Couldn't find or add package '$package'!\n";
  }
  $self->{queries}->{get_package_id}->finish();

  my $fileroot = $self->makeFileHierarchy($package, $files);
  $self->addFileTree($package_id, $fileroot, 0);
  $self->{dbh}->commit();
}

sub getPackageFiles {
  my($self, $package_id) = @_;
  return $self->selectAll("get_package_files", $package_id);
}

sub getPackages {
  my($self) = @_;
  return $self->selectAll("get_packages");
}

sub getPackageID {
  my($self, $package_name) = @_;
  return $self->selectOne("get_package_id", $package_name);
}

sub getFileID {
  my($self, $path) = @_;
  return $self->selectOne("get_file_id", $path);
}

sub getDirectoryFiles {
  my($self, $file_id) = @_;
  return $self->selectAll("get_directory_files", $file_id);
}

# ===Internal Functions===

sub execQuery {
  my($self, $qname, @bindvals) = @_;

  my $queries = $self->{queries};
  my $query = $queries->{$qname};
  $query = $queries->{$qname} = $self->prepare($qname) if !$query;

  return $query->execute(@bindvals) ? $query : undef;
}

sub selectOne {
  my($self, $qname, @bindvals) = @_;

  my $query = $self->execQuery($qname, @bindvals);
  my($val) = $query->fetchrow_array();
  $query->finish();
  return $val;
}

sub selectAll {
  my($query, @bindvals) = @_;
  my $query = $self->execQuery($query, @bindvals);
  my $ret = $query->fetchall_arrayref({});
  $query->finish();
  return @$ret;
}

sub makeFileHierarchy {
  my($self, $pkg, $files) = @_;
  my %root = ("." => "", ".." => undef, "/path/" => "");

  foreach my $file (@$files) {
    my $path = delete $file->{path};
    if (not $path =~ s!^%p/!!) {
      warn "$pkg has path not in %p: $path\n";
      next;
    }

    $file->{fullpath} = $path;
    $file->{isdir} = ($file->{flags} =~ /^d/ ? 1 : 0);

    my @pathbits = split(m!/!, $path);

    my $finkroot = \%root;
    my $fullpath = "";
    foreach my $pathbit (@pathbits) {
      $fullpath .= "/" if $fullpath;
      $fullpath .= $pathbit;
      $finkroot->{$pathbit} ||= {".." => $finkroot, "." => $pathbit, "/path/" => $fullpath};
      $finkroot = $finkroot->{$pathbit};
    }

    $finkroot->{"/versions/"} ||= [];
    push @{$finkroot->{"/versions/"}}, $file;
    $file->{pkg} = $pkg;
  }

  return \%root;
}

sub addFileTree {
  my($self, $pkgid, $file, $parent_id) = @_;

  my $file_id = $self->selectOne("get_file_id", $file->{"/path/"});
  if(!$file_id) {
    $self->execQuery("add_file_path", $parent_id, $file->{"."}, $file->{"/path/"});
    $file_id = $self->selectOne("get_file_id", $file->{"/path/"}) or
      die "Couldn't fetch or insert file ID for ".$file->{"/path/"}."!\n";
  }

  if ($file->{"/versions/"}) {
    foreach my $filever (@{$file->{"/versions/"}}) {
      $self->execQuery("add_file_version",
		       $pkgid,
		       $filever->{isdir},
		       $filever->{fullpath},
		       $file_id,
		       $filever->{size},
		       $filever->{user},
		       $filever->{group},
		       $filever->{flags}
		      );
    }
  }

  foreach my $subfile (keys %$file) {
    next if $subfile eq "." or $subfile eq ".." or $subfile eq "/versions/" or $subfile eq "/path/";
    $self->addFileTree($pkgid, $file->{$subfile}, $file_id);
  }
}

sub prepare {
  my($self, $qname) = @_;
  return $self->{dbh}->prepare($dbqueries{$qname});
}

1;
