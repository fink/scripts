package BFData;
use strict;
use warnings;

sub new {
  my %params = @_;
  die "BFData::new requires 'store' argument!\n" unless $params{store};
  eval "require BFData::$params{store};";
  die $@ if $@;
  $params{store}->new(@_);
}

1;
