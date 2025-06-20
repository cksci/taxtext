#!/usr/bin/env perl
use warnings;
use strict;
use File::Basename;
my $dir = dirname($0);

use FindBin;
use lib "$FindBin::Bin/../lib";
use Tax::Txt;

my %OPT;
use Getopt::Long;
GetOptions(\%OPT,"account=s");

my $USAGE = "$0 -account Name <Questrade Activity csv> ...\n";
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

  my $base = basename($file);
  $base =~ s/\.\w+//g;
  $base =~ tr/a-z/A-Z/;
  $base = $OPT{account} if (exists $OPT{account});

  my %cols;
  while (<IN>) {
    chomp;
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

    $csv->parse($_);
    my @bits = $csv->fields();

    my $symbol;
    if (exists $cols{"Symbol"}) {
      $symbol = $bits[$cols{"Symbol"}];
    } elsif (exists $cols{"Equity Symbol"}) {
      $symbol = $bits[$cols{"Equity Symbol"}];
    } else {
      die
    }
    $symbol =~ s/\s.*//g;

    my $qty;
    if (exists $cols{"Qty"}) {
      $qty = $bits[$cols{"Qty"}];
    } elsif (exists $cols{"Open qty"}) {
      $qty = $bits[$cols{"Open qty"}];
    } elsif (exists $cols{"Quantity"}) {
      $qty = $bits[$cols{"Quantity"}];
    } else {
      die;
    }

    my $curr;
    if (exists $cols{"Curr"}) {
      $curr = $bits[$cols{"Curr"}];
    } elsif (exists $cols{"Currency"}) {
      $curr = $bits[$cols{"Currency"}];
    } else {
      die;
    }

    my $cost;
    if (exists $cols{"Cost/share"}) {
      $cost = $bits[$cols{"Cost/share"}];
    } elsif (exists $cols{"Avg price"}) {
      $cost = $bits[$cols{"Avg price"}];
    } elsif (exists $cols{"Cost Per Share"}) {
      $cost = $bits[$cols{"Cost Per Share"}];
    } else {
      die;
    }

    next unless (defined $cost);

    print OUT "HOLD $base $symbol.$curr $symbol $curr OPEN ON - EQUITY $qty $cost 0 0 0 0 0 0 0 0 0 0 0 0 0\n";
  }
}

