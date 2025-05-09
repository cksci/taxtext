#!/usr/bin/env perl
use warnings;
use strict;
use Time::Local;

use File::Basename;
use FindBin;
use lib "$FindBin::Bin/../lib";
use Tax::Txt;

my $USAGE = "$0 <taxtxt>\n";
die $USAGE unless (@ARGV == 1);

my $file = $ARGV[0];
open(IN,$file) || die "Error: Can't read file '$file': $!\n";

my %db;
while (<IN>) {
  if (/^\s*HOLD/) {
    my @bits = split;
    my $account = $bits[1];
    my $div_tot_cad = $bits[15];
    my $value_cad = $bits[20];

    if (!exists $db{$account}{div}) {
      $db{$account}{div} = 0;
      $db{$account}{value} = 0;
    }
    $db{$account}{div} += $div_tot_cad;
    $db{$account}{value} += $value_cad;
  }
}

open(OUT,"|tabulate.pl") || die "Error: Can't pipe to tabulate.pl: $!\n";
foreach my $account (sort keys %db) {
  my $yield = fmt_money(100.0*$db{$account}{div}/$db{$account}{value});
  my $div = fmt_money($db{$account}{div});
  my $div_month = fmt_money($db{$account}{div}/12.0);
  my $value = fmt_money($db{$account}{value});
  print OUT "$account $yield $div $div_month $value\n";
}

