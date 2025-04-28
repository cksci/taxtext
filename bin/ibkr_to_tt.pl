#!/usr/bin/env perl
use warnings;
use strict;

use File::Basename;
use FindBin;
use lib "$FindBin::Bin/../lib";
use Tax:Txt;

my $USAGE = "$0 <IBKR Activity csv>\n";
die $USAGE unless (@ARGV == 1);

my $file = $ARGV[0];
open(IN,$file) || die "Error: Can't read file '$file': $!\n";

my %cols;
while (<IN>) {
  chomp;
  if (/^Trades,Header/) {
    my @bits = split(/,/);
    for (my $i=0; $i<@bits; $i++) {
      $cols{$bits[$i]} = $i;
    }
    last;
  }
}

open(OUT,"|tabulate.pl") || die "Error: Can't pipe to tabulate.pl: $!\n";

while (<IN>) {
  chomp;
  if (/^Trades/) {

    my @bits = split(/,/);

    my $activity    = $bits[$cols{"DataDiscriminator"}];
    next unless ($activity eq "Order");

    my $date        = convert_date($bits[$cols{"Date/Time"}]);
    my $date_settle = $date;
    my $symbol      = $bits[$cols{"Symbol"}];
    my $quantity    = $bits[$cols{"Quantity"}];
    my $price       = fmt_money($bits[$cols{"T. Price"}]);
    my $fee         = abs(fmt_money($bits[$cols{"Comm/Fee"}]));
    my $currency    = $bits[$cols{"Currency"}];
    my $value       = fmt_money(abs($bits[$cols{"Basis"}]));
    my $code        = $bits[$cols{"Code"}];

    print OUT "BUYSELL $date $date_settle $symbol.$currency $quantity $currency $price $fee $value\n";
  }
}

