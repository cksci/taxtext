#!/usr/bin/env perl
use warnings;
use strict;

use File::Basename;
use FindBin;
use lib "$FindBin::Bin/../lib";
use Tax::Txt;

my $USAGE = "$0 <RBC holdings csv> ...\n";
die $USAGE unless (@ARGV > 0);

open(OUT,"|tabulate.pl -r") || die "Error: Can't pipe to tabulate.pl: $!\n";

print OUT "HEADER ACCOUNT SYMBOL SYMBOL_YAHOO CURRENCY STATUS RISK SECTOR TYPE QUANTITY COST PRICE CHANGE GAIN_PCT DIV YIELD DIV_TOT DIV_TOT_CAD BOOK VALUE GAIN BOOK_CAD VALUE_CAD GAIN_CAD\n";
foreach my $file (@ARGV) {
  open(IN,$file) || die "Error: Can't read file '$file': $!\n";
  my $base = basename($file);
  $base =~ s/\.\w+//g;
  $base =~ tr/a-z/A-Z/;

  my %cols;
  while (<IN>) {
    chomp;
    if (/^\s*,Product/) {
      s/\"//g;
      my @bits = split(/,/);
      for (my $i=0; $i<@bits; $i++) {
        $cols{$bits[$i]} = $i;
      }
      last;
    }
  }

  while (<IN>) {
    chomp;
    last if (/^\s*$/);
    s/^\s*\"|\"\s*$//g;
    s/"//g;

    my @bits = split(/\s*,\s*/);

    my $symbol = $bits[$cols{"Symbol"}];
    my $qty    = $bits[$cols{"Quantity"}];
    my $cost   = $bits[$cols{"Average Cost"}];
    my $curr   = $bits[$cols{"Currency"}];
    $symbol    = "$symbol.$curr";
    next unless (abs($qty) > 1e-3);

    my $symbol_yahoo = $symbol;
    $symbol_yahoo =~ s/\.PR\./-P/;
    $symbol_yahoo =~ s/\.UN/-UN/;
    $symbol_yahoo =~ s/\.CAD/.TO/;
    $symbol_yahoo =~ s/\.USD//;

    print OUT "HOLD $base $symbol $symbol_yahoo $curr OPEN ON -  - $qty $cost 0 0 0 0 0 0 0 0 0 0 0 0 0\n";
  }
}
