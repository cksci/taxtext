#!/usr/bin/env perl
use warnings;
use strict;

my %OPT;
use Getopt::Long;
GetOptions(\%OPT,"next","first","last");

my %db;
foreach my $file (@ARGV) {
  if ($file =~ /(\d+)\./) {
    $db{$1} = $file
  }
}

my @nums = sort {$a<=>$b} keys %db;
if (@nums > 0) {
  if (exists $OPT{first}) {
    print $db{$nums[0]};
  } elsif (exists $OPT{last}) {
    print $db{$nums[$#nums]};
  } elsif (exists $OPT{next}) {
    my $num_next = $nums[$#nums]+1;
    my $last = $db{$nums[$#nums]};
    $last =~ s/(\d+)./${num_next}./;
    print $last;
  }
}

