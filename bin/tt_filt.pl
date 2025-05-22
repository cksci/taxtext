#!/usr/bin/env perl
use warnings;
use strict;
use Time::Local;
use File::Basename;
my $dir = dirname($0);

use FindBin;
use lib "$FindBin::Bin/../lib";
use Tax::Txt;

my %OPT;
use Getopt::Long;
GetOptions(\%OPT,"days=i","month=i","year=i");

my $USAGE = "$0 <taxtxt>\n";
die $USAGE unless (@ARGV == 1);

my $file = $ARGV[0];
open(IN,$file) || die "Error: Can't read file '$file': $!\n";

my ($sec,$min,$hour,$mday,$mon,$year) = localtime();
my $epoch = timelocal(0,0,12,$mday,$mon,$year);

my %db;
while (<IN>) {
  if (/^\s*\S+\s+(\d+)\/(\d+)\/(\d+)\s+/) {
    my ($m,$d,$y) = ($1,$2,$3);
    $m -= 1;
    $y -= 1900;
    my $epoch2 = timelocal(0,0,12,$d,$m,$y);

    if (exists $OPT{days}) {
      my $epoch3 = $epoch - 60*60*24*$OPT{days};
      if ($epoch2 > $epoch3) {
        push @{$db{$epoch2}}, $_;
      }
    }
    if (exists $OPT{months}) {
      my $epoch3 = $epoch - 60*60*24*30*$OPT{months};
      if ($epoch2 > $epoch3) {
        push @{$db{$epoch2}}, $_;
      }
    }
    if (exists $OPT{years}) {
      my $epoch3 = $epoch - 60*60*24*365*$OPT{years};
      if ($epoch2 > $epoch3) {
        push @{$db{$epoch2}}, $_;
      }
    }
  }
}

open(OUT,"|$dir/tt_tab.pl") || die "Error: Can't pipe to '$dir/tt_tab.pl': $!\n";
foreach my $epoch (sort {$a<=>$b} keys %db) {
  print OUT @{$db{$epoch}};
}

