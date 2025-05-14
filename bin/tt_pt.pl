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

print OUT "HEADER ACCOUNT SYMBOL SYMBOL_YAHOO CURRENCY STATUS RISK SECTOR TYPE QUANTITY COST PRICE CHANGE GAIN_PCT DIV YIELD DIV_TOT DIV_TOT_CAD BOOK VALUE GAIN BOOK_CAD VALUE_CAD GAIN_CAD\n";
foreach my $fh (@fhs) {
  while (<$fh>) {
    if (/^\s*COST\s+\S+\s+\S+\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)/i) {
      my ($symbol,$qty,$curr,$cost) = ($1,$2,$3,$4);

      my $symbol_yahoo = $symbol;
      $symbol_yahoo =~ s/\.PR\./-P/;
      $symbol_yahoo =~ s/\.UN/-UN/;
      $symbol_yahoo =~ s/\.CAD/.TO/;
      $symbol_yahoo =~ s/\.USD//;

      print OUT "HOLD - $symbol $symbol_yahoo $curr OPEN ON -  - $qty $cost 0 0 0 0 0 0 0 0 0 0 0 0 0\n";
    }
  }
}
