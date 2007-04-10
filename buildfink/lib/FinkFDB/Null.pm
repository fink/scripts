package FinkFDB::Null;
use strict;
use warnings;
use base qw(FinkFDB);

sub new {
  my($pkg, %params) = @_;
  my $self = {};
  my $class = ref($pkg) || $pkg || __PACKAGE__;
  bless $self, $class;

  $self->SUPER::new(%params);
  return $self;
}
sub initialize { }
sub finish { }
sub addPackageFiles { }
sub getPackageFiles { return qw() }
sub getPackages { return qw() }
sub getDirectoryFiles { qw() }

1;
