#!/usr/bin/env perl
use warnings;
use strict;

my @tmp;
while (<>) {
  push @tmp,$_;
}
print reverse(@tmp);
