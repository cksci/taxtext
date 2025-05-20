#!/usr/bin/env perl
use warnings;
use strict;

use File::Basename;
use FindBin;
use lib "$FindBin::Bin/../lib";
use Tax::Txt;

my $USAGE = "$0 <IBKR holdings csv> ...\n";
die $USAGE unless (@ARGV > 0);

use Text::CSV;
my $csv = Text::CSV->new({
  binary    => 1,   # Allow special characters
  auto_diag => 1,   # Report parsing errors
});

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
    if (/^\s*Open\s+Positions\s*,\s*Header/) {
      my @bits = split(/,/);
      for (my $i=0; $i<@bits; $i++) {
        $cols{$bits[$i]} = $i;
      }
      last;
    }
  }

  while (<IN>) {
    chomp;

    if (/^\s*Open\s+Positions\s*,\s*Data\s*,\s*Summary/) {

      $csv->parse($_);
      my @bits = $csv->fields();

      my $symbol   = fmt_symbol($bits[$cols{"Symbol"}]);
      my $quantity = fmt_qty($bits[$cols{"Quantity"}]);
      $quantity *= 100 if (tt_is_option($symbol));

      my $cost     = fmt_money($bits[$cols{"Cost Price"}]);
      my $curr     = $bits[$cols{"Currency"}];

      next unless (abs($quantity) > 1e-3);

      $symbol    = "$symbol.$curr";
      my $symbol_yahoo = tt_make_yahoo_symbol($symbol);


      print OUT "HOLD $base $symbol $symbol_yahoo $curr OPEN ON -  - $quantity $cost 0 0 0 0 0 0 0 0 0 0 0 0 0\n";
    }
  }
}
