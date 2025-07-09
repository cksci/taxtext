#!/usr/bin/env perl
use warnings;
use strict;

my %OPT;
use Getopt::Long;
GetOptions(
  \%OPT,
  "yield",
  "div_tot",
  "div_tot_cad",
  "gain_pct",
  "gain",
  "gain_cad",
  "value",
  "value_cad"
);

use FindBin;
use lib "$FindBin::Bin/../lib";
use Tax::Txt;

my $USAGE = "$0 [-yield|-div_tot|-gain_pct|-gain|gain_cad|-value|-value_cad]  <pt text> ...\n";
die $USAGE unless (@ARGV > 0);

my @fhs;
if (@ARGV) {
  foreach my $file (@ARGV) {
    open my $fh, '<', $file or die "Could not open '$file': $!";
    push @fhs, $fh;
  }
} else {
  push @fhs, *STDIN;
}

my @fg;
my %db;

foreach my $fh (@fhs) {
  my %cols;

  while (<$fh>) {
    s/^\s+//;
    s/\s+$//;

    if (/^\s*HEADER/) {
      %cols = tt_parse_header($_);
    }

    if (/^\s*HOLD/) {

      die "Error: Didn't find header before HOLD lines!\n" if (scalar keys %cols == 0);

      my @bits        = split;
      my $symbol      = $bits[$cols{SYMBOL}];
      my $yield       = $bits[$cols{YIELD}];
      my $div_tot     = $bits[$cols{DIV_TOT}];
      my $div_tot_cad = $bits[$cols{DIV_TOT_CAD}];
      my $gain_pct    = $bits[$cols{GAIN_PCT}];
      my $gain        = $bits[$cols{GAIN}];
      my $gain_cad    = $bits[$cols{GAIN_CAD}];
      my $value       = $bits[$cols{VALUE}];
      my $value_cad   = $bits[$cols{VALUE_CAD}];

      if (exists $OPT{yield}) {
        print "$symbol $yield\n";
      } elsif (exists $OPT{div_tot}) {
        print "$symbol $div_tot\n";
      } elsif (exists $OPT{div_tot_cad}) {
        print "$symbol $div_tot_cad\n";
      } elsif (exists $OPT{gain_pct}) {
        print "$symbol $gain_pct\n";
      } elsif (exists $OPT{gain}) {
        print "$symbol $gain\n";
      } elsif (exists $OPT{gain_cad}) {
        print "$symbol $gain_cad\n";
      } elsif (exists $OPT{value}) {
        print "$symbol $value\n";
      } elsif (exists $OPT{value_cad}) {
        print "$symbol $value_cad\n";
      }
    }
  }
}
