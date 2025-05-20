#!/usr/bin/env perl
use warnings;
use strict;

use File::Basename;
use FindBin;
use lib "$FindBin::Bin/../lib";
use Tax::Txt;

my $USAGE = "$0 <IBKR Activity csv> ...\n";
die $USAGE unless (@ARGV > 0);

use Text::CSV;
my $csv = Text::CSV->new({
  binary    => 1,   # Allow special characters
  auto_diag => 1,   # Report parsing errors
});

open(OUT,"|tabulate.pl") || die "Error: Can't pipe to tabulate.pl: $!\n";

foreach my $file (@ARGV) {
  open(IN,$file) || die "Error: Can't read file '$file': $!\n";

  my %cols;
  while (<IN>) {
    chomp;
    if (/^\s*Trades\s*,\s*Header/) {
      my @bits = split(/,/);
      for (my $i=0; $i<@bits; $i++) {
        $cols{$bits[$i]} = $i;
      }
      last;
    }
  }

  while (<IN>) {
    chomp;

    # TODO: Need to make this smarter since it's also catching forex
    if (/^\s*Trades\s*,\s*Data\s*,\s*Order\s*,.*(Stocks|Options)/) {

      $csv->parse($_);
      my @bits = $csv->fields();

      my $activity    = $bits[$cols{"DataDiscriminator"}];
      next unless ($activity eq "Order");

      my $date        = convert_date($bits[$cols{"Date/Time"}]);
      my $date_settle = $date;
      my $symbol      = fmt_symbol($bits[$cols{"Symbol"}]);
      my $quantity    = fmt_qty($bits[$cols{"Quantity"}]);
      $quantity *= 100 if (tt_is_option($symbol));
      my $price       = fmt_money($bits[$cols{"T. Price"}]);
      my $fee         = abs(fmt_money($bits[$cols{"Comm/Fee"}]));
      my $currency    = $bits[$cols{"Currency"}];
      my $value       = fmt_money(abs($bits[$cols{"Basis"}]));
      my $code        = $bits[$cols{"Code"}];

      print OUT "BUYSELL $date $date_settle $symbol.$currency $quantity $currency $price $fee $value\n";
    }
  }
}

