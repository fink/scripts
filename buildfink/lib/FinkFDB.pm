package FinkFDB;
use strict;
use warnings;

sub new {
  my($self, %params) = @_;

  # Some magic to let SUPER->new work from subclasses...
  if(!ref($self) or !$self->isa("FinkFDB")) {
    die "FinkFDB::new requires 'store' argument!\n" unless $params{store};
    eval "require FinkFDB::$params{store};";
    die $@ if $@;
    "FinkFDB::$params{store}"->new(%params);
  } else {
    # Common initialization code would go here
  }
}

sub initialize {
  warn "initialize was not subclassed!";
}

sub finish {
  warn "finish was not subclassed!";
}

sub addPackageFiles {
	warn "addPackageFiles was not subclassed!";
}

sub getPackageFiles {
  warn "getPackageFiles was not subclassed!";
  return qw();
}

sub getDirectoryFiles {
  warn "getDirectoryFiles was not subclassed!";
  return qw();
}

sub getPackages {
  warn "getPackages was not subclassed!";
  return qw();
}

1;
