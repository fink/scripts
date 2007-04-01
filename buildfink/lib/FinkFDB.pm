package FinkFDB;
use strict;
use warnings;

sub new {
  my($self, %params) = @_;
  die "FinkFDB::new requires 'store' argument!\n" unless $params{store};
  eval "require FinkFDB::$params{store};";
  die $@ if $@;
  "FinkFDB::$params{store}"->new(%params);
}

1;
