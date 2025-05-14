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
    if (/^Symbol/) {
      my @bits = split(/,/);
      for (my $i=0; $i<@bits; $i++) {
        $cols{$bits[$i]} = $i;
      }
      last;
    }
  }

  while (<IN>) {
    chomp;
    my $curr = "CAD";
    if (s/US\$//g) {
      $curr = "USD";
    }
    s/\$//g;

    $csv->parse($_);
    my @bits = $csv->fields();
    my $symbol = $bits[$cols{"Symbol"}];
    my $qty = $bits[$cols{"Quantity"}];
    $qty *= 100;
    my $cost = $bits[$cols{"Total Cost"}];
    $cost =~ s/,//g;
    $cost /= abs($qty);

    if ($symbol =~ /(\S+)\s+([\d\.]+)\s+(\d+)\s+(\w+)\s+(\d+)\s+(Call|Put)/i) {
      my ($ticker,$strike,$day,$month,$year,$what) = ($1,$2,$3,$4,$5,$6);

      $month  = month_num($month);
      $day    = sprintf("%02d",$day);
      $month  = sprintf("%02d",$month);
      $year   = sprintf("%02d",$year);
      $strike = sprintf("%08d",1000*$strike);
      if ($what =~ /Call/i) {
        $what = "C";
      } else {
        $what = "P";
      }

      $symbol = "${ticker}${year}${month}${day}${what}${strike}";
    } else {
    }
    print OUT "HOLD Webull $symbol.$curr $symbol $curr OPEN ON - OPTION $qty $cost 0 0 0 0 0 0 0 0 0 0 0 0 0\n";
  }
}

