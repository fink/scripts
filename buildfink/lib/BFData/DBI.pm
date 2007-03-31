package BFData::DBI;
use strict;
use warnings;
use DBI;
our @ISA = qw(BFData);

our %dbqueries = (
		  add_package => "INSERT INTO packages(package_name) VALUES (?)",
		  add_file_path => "INSERT INTO file_paths(parent_id, file_name, fullpath) VALUES (?, ?, ?)",
		  get_package_id => "SELECT package_id FROM packages WHERE package_name = ?",
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
  if ($self->{dbtype} eq "sqlite") {
    die "Must specify db for DBI SQLite.\n" unless $params{db};
    $dbstr = sprintf("dbi:SQLite:dbname=%s", $params{db});
  } else {
    die "Unknown dbtype; valid values: sqlite\n";
  }

  $self->{dbh} = DBI->connect($dbstr, $params{user}, $params{password}, \%dbattrs);
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

sub addPackageFiles {
  my($self, $package, @files) = @_;

  if (!$self->{queries}->{get_package_id}->execute($package)) {
    $self->addPackage($package);
    $self->{queries}->{get_package_id}->execute($package) or
      die "Couldn't find or add package '$package'!\n";
  }
  my($package_id) = $self->{queries}->{get_package_id}->fetchrow_array();
  $self->{queries}->{get_package_id}->finish();

  my $fileroot = $self->makeFileHierarchy($package, \@files);
  $self->addFileTree($package_id, $fileroot, 0);
  $self->{dbh}->commit();
}

sub makeFileHierarchy {
  my($self, $pkg, $files) = @_;
  my %root = ("." => "", ".." => undef);

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

  $self->{queries}->{add_file_path}->execute($parent_id, $file->{"."}, $file->{"/path/"});
  my $file_id = $dbh->last_insert_id(undef, undef, undef, undef);

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
