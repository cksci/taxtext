#!/usr/bin/env perl
use warnings;
use strict;
use File::Basename;
my $dir = dirname($0);

use FindBin;
use lib "$FindBin::Bin/../lib";
use Tax::Txt;

my $USAGE = "$0 <Coinbase Activity csv> ...\n";
die $USAGE unless (@ARGV > 0);

use Text::CSV;
my $csv = Text::CSV->new({
  binary    => 1,   # Allow special characters
  auto_diag => 1,   # Report parsing errors
});

# TODO: Date order should be auto-detected not assumed
open(OUT,"|$dir/reverse.pl | $dir/tt_tab.pl") || die "Error: Can't pipe to '$dir/tt_tab.pl': $!\n";

foreach my $file (@ARGV) {
  open(IN,$file) || die "Error: Can't read file '$file': $!\n";

  my %cols;
  while (<IN>) {
    chomp;
    if (/^\s*ID,Timestamp,/) {
      my @bits = split(/,/);
      for (my $i=0; $i<@bits; $i++) {
        $cols{$bits[$i]} = $i;
      }
      last;
    }
  }

  while (<IN>) {
    chomp;
    s/\$//g;

    $csv->parse($_);
    my @bits = $csv->fields();

    if ($bits[$cols{"Transaction Type"}] =~ /buy|sell|staking\s+income/i) {
      
      my $date = convert_date($bits[$cols{"Timestamp"}]);
      my $symbol = $bits[$cols{"Asset"}];
      my $qty = $bits[$cols{"Quantity Transacted"}];
      my $price = $bits[$cols{"Price at Transaction"}];
      my $curr = $bits[$cols{"Price Currency"}];
      my $value = $bits[$cols{"Total (inclusive of fees and/or spread)"}];
      my $fee = $bits[$cols{"Fees and/or Spread"}];

      print OUT "BUYSELL $date $date $symbol-$curr $qty $curr $price $fee $value\n";
      print OUT "DIVIDEND $date $date $symbol-$curr 1.0 $curr $value 0.0 $value $value\n";
    }
  }
}
