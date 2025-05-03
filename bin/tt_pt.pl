#!/usr/bin/env perl
use warnings;
use strict;
open(OUT,"|tabulate.pl") || die "Error: Can't pipe to 'tabulate.pl': $!\n";


my @fhs;

if (@ARGV) {
  foreach my $file (@ARGV) {
    open my $fh, '<', $file or die "Could not open '$file': $!";
    push @fhs, $fh;
  }
} else {
  push @fhs, *STDIN;
}

print OUT "HEADER ACCOUNT STATUS RISK SECTOR SYMBOL CURRENCY QUANTITY COST PRICE CHANGE_PCT GAIN_PCT DIV YIELD DIV_TOT DIV_TOT_CAD BOOK VALUE GAIN BOOK_CAD VALUE_CAD GAIN_CAD\n";
foreach my $fh (@fhs) {
  while (<$fh>) {
    if (/^\s*COST\s+\S+\s+\S+\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)/i) {
      my ($symbol,$qty,$curr,$cost) = ($1,$2,$3,$4);
      print OUT "HOLD - OPEN ON - $symbol $curr $qty $cost 0 0 0 0 0 0 0 0 0 0 0 0 0\n";
    }
  }
}
