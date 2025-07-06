#!/usr/bin/env perl
use warnings;
use strict;
use File::Basename;
my $dir = dirname($0);

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

open(OUT,"|$dir/tt_tab.pl") || die "Error: Can't pipe to '$dir/tt_tab.pl': $!\n";
print OUT "HEADER ACCOUNT SYMBOL SYMBOL_YAHOO CURRENCY STATUS RISK SECTOR TYPE QUANTITY COST PRICE CHANGE GAIN_PCT DIV YIELD DIV_TOT DIV_TOT_CAD BOOK VALUE GAIN BOOK_CAD VALUE_CAD GAIN_CAD\n";

foreach my $file (@ARGV) {
  open(IN,$file) || die "Error: Can't read file '$file': $!\n";

  my %cols;
  while (<IN>) {
    chomp;
    s/"//g;
    s/\s+/ /g;
    if (/Symbol,/) {
      my @bits = split(/,/);
      for (my $i=0; $i<@bits; $i++) {
        $cols{$bits[$i]} = $i;
      }
      last;
    }
  }

  while (<IN>) {
    chomp;
    next if (/Cover\s+Option/); # Webull informatively groups a position and it's covered call

    my $curr = "CAD";
    if (s/US\$//g) {
      $curr = "USD";
    }

    $csv->parse($_);
    my @bits = $csv->fields();
    #use Data::Dumper;
    #print Dumper(\@bits);
    #print Dumper(\%cols);

    my $qty = $bits[$cols{"Quantity"}];
    next unless (defined $qty && $qty =~ /\d/);
    my $type = "EQUITY";

    my $symbol;
    if (exists $cols{"Name"}) { 
      $symbol = fmt_symbol($bits[$cols{"Name"}]);
      if ($bits[$cols{"Name"}] =~ /(\S+)\s+\$?\d+/) {
        $qty *= 100;
        $type = "OPTION";
      }
    } elsif (exists $cols{"Symbol"}) {
      $symbol = fmt_symbol($bits[$cols{"Symbol"}]);
      if ($bits[$cols{"Symbol"}] =~ /(\S+)\s+\$?\d+/) {
        $qty *= 100;
        $type = "OPTION";
      }
    } else {
      die "Error: Can't find Symbol on line '$_'\n";
    }

    my $cost;
    if (exists $cols{"Avg Price"}) {
      $cost = $bits[$cols{"Avg Price"}];
    } elsif (exists $cols{"Total Cost"}) {
      $cost = $bits[$cols{"Total Cost"}];
      $cost =~ s/,//g;
      $cost /= abs($qty);
    } 

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
    print OUT "HOLD Webull $symbol.$curr $symbol $curr OPEN ON - $type $qty $cost 0 0 0 0 0 0 0 0 0 0 0 0 0\n";
  }
}

