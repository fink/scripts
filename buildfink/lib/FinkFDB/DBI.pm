package FinkFDB::DBI;
use strict;
use warnings;
use DBI;
our @ISA = qw(FinkFDB);

our %dbqueries = (
		  add_package => "INSERT INTO packages(package_name) VALUES (?)",
		  add_file_path => "INSERT INTO file_paths(parent_id, file_name, fullpath) VALUES (?, ?, ?)",
		  get_package_id => "SELECT package_id FROM packages WHERE package_name = ?",
		  get_file_id => "SELECT file_id FROM file_paths WHERE fullpath = ?",
		  add_file_version => <<EOF);
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
  foreach my $key (keys %dbqueries) {
    $self->{queries}->{$key} = $self->prepare($dbqueries{$key});
  }

  return $self;
}

sub addPackage {
  my($self, $package) = @_;
  $self->{queries}->{add_package}->execute($package);
  $self->{dbh}->commit();
}

sub selectOne {
  my($self, $qname, @bindvals) = @_;

  my $query = $self->{queries}->{$qname};
  $query->execute(@bindvals) or return;
  my($val) = $query->fetchrow_array();
  $query->finish();
  return $val;
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
    $self->{queries}->{add_file_path}->execute($parent_id, $file->{"."}, $file->{"/path/"});
    $file_id = $self->selectOne("get_file_id", $file->{"/path/"}) or
      die "Couldn't fetch or insert file ID for ".$file->{"/path/"}."!\n";
  }

  if ($file->{"/versions/"}) {
    foreach my $filever (@{$file->{"/versions/"}}) {
      $self->{queries}->{add_file_version}->execute(
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
  my($self, $stmt) = @_;
  return $self->{dbh}->prepare($stmt);
}

1;
