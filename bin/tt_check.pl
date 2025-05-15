#!/usr/bin/env perl
use warnings;
use strict;
use Time::Local;

use FindBin;
use lib "$FindBin::Bin/../lib";
use Tax::Txt;

my $USAGE = "$0 <taxtxt>\n";
die $USAGE unless (@ARGV > 0);

my %db;
my %dup_curr;
my %dup_line;

foreach my $file (@ARGV) {
  open(IN,$file) || die "Error: Can't read file '$file': $!\n";

  while (<IN>) {

    # Check for duplicates
    my $tmp = $_;
    $tmp =~ s/\s+/ /g;
    $tmp =~ s/^\s+//g;
    $tmp =~ s/\s*$//g;

    if (exists $dup_line{$tmp}) {
      warn "# Warning: Found duplicated line: $tmp\n" unless ($tmp =~ /^DEPOSIT/); # Ignore duplicate deposits ex. rewards
    }
    $dup_line{$tmp} = 1;

    if (/^\s*(BUYSELL|COST)/i) {
      my @bits = split;

      my $what        = $bits[0];
      my $date        = $bits[1];
      my $date_settle = $bits[2];
      my $symbol      = $bits[3];
      my $quantity    = $bits[4];
      my $currency    = $bits[5];
      my $price       = $bits[6];
      my $fee         = $bits[7];
      my $value       = $bits[8];

      $db{$symbol}{$currency} = 1;
      
      my $key = "$what $date $date_settle $symbol";
      $dup_curr{$key}{$quantity} = 1;
    }
  }
}

foreach my $symbol (sort keys %db) {
  my @currencies = keys %{$db{$symbol}};
  if (@currencies > 1) {
    warn "# Warning: Multiple currencies for symbol '$symbol' " . join(", ",@currencies) . " \n";
  }
}

foreach my $key (sort keys %dup_curr) {
  my @quantities = sort {$a <=> $b} keys %{$dup_curr{$key}};
  my $pos = 0;
  my $neg = 0;
  foreach my $quantity (@quantities) {
    $neg = 1 if ($quantity < 0);
    $pos = 1 if ($quantity > 0);
  }
  if ($pos && $neg) {
    warn "# Warning: Found same day positive and negative BUYSELL for $key\n";
  }
}
