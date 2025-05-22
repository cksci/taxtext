#!/usr/bin/env perl
use warnings;
use strict;
use Time::Local;
use File::Basename;
my $dir = dirname($0);

use FindBin;
use lib "$FindBin::Bin/../lib";
use Tax::Txt;

my $USAGE = "$0 <taxtxt> ...\n";
die $USAGE unless (@ARGV > 0);

my %db;
foreach my $file (@ARGV) {
  open(IN,$file) || die "Error: Can't read file '$file': $!\n";

  while (<IN>) {
    if (/^\s*\S+\s+(\d+)\/(\d+)\/(\d+)\s+/) {
      my ($month,$day,$year) = ($1,$2,$3);
      $month--;
      my $epoch = timelocal(0,0,16,$day,$month,$year);
      push @{$db{$epoch}}, $_;
    }
  }
}

open(OUT,"|$dir/tt_tab.pl") || die "Error: Can't pipe to '$dir/tt_tab.pl': $!\n";
foreach my $epoch (sort {$a<=>$b} keys %db) {
  print OUT @{$db{$epoch}};
}
