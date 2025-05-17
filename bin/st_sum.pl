#!/usr/bin/env perl
use warnings;
use strict;
use Time::Local;

my %OPT;
use Getopt::Long;
GetOptions(\%OPT,"year=s");

use File::Basename;
use FindBin;
use lib "$FindBin::Bin/../lib";
use Tax::Txt;

my $USAGE = "$0 <portfoliotext> ...\n";
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

my %db;

my $zero = fmt_money2(0.0);

foreach my $fh (@fhs) {
  my %cols;

  while (<$fh>) {
    chomp;
    s/#.*//g;
    s/^\s+//;
    s/\s+$//;
    s/\s+/ /g;

    if (/^NAV\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)/i) {
      my ($date,$nav,$cash_pct,$cs_ticker,$ps1_ticker,$ps2_ticker,$cs_qty,$ps1_qty,$ps2_qty,$cs_price,$ps1_price,$ps2_price) = ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12);
    } elsif (/^WEIGHT\s+(\S+)\s+(\S+)\s+(\S+)/i) {
      my ($date,$ticker,$pct) = ($1,$2,$3);
      $db{$
    }

  }
}

