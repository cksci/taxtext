#!/usr/bin/env perl
use warnings;
use strict;
open(OUT,"|tabulate.pl") || die "Error: Can't pipe to 'tabulate.pl': $!\n";

while (<>) {
  if (/^\s*BUYSELL\s+\S+\s+\S+\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)/i) {
    my ($symbol,$qty,$curr,$cost) = ($1,$2,$3,$4);
    print OUT "HOLD - OPEN ON - $symbol $qty $cost - - - - - - - - - - - - -\n";
  }
}
