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

    my $symbol = $bits[$cols{"Symbol"}];
    $symbol =~ s/\s.*//g;
    my $qty = $bits[$cols{"Qty"}];
    my $curr = $bits[$cols{"Curr"}];
    my $cost = $bits[$cols{"Cost/share"}];

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
    print OUT "HOLD $base $symbol.$curr $symbol $curr OPEN ON - OPTION $qty $cost 0 0 0 0 0 0 0 0 0 0 0 0 0\n";
  }
}

