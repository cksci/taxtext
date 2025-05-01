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
  if (/^\s*\S+\s+(\d+)\/(\d+)\/(\d+)\s+/) {
    my ($month,$day,$year) = ($1,$2,$3);
    $month--;
    my $epoch = timelocal(0,0,16,$day,$month,$year);
    push @{$db{$epoch}}, $_;
  }
}

open(OUT,"|tabulate.pl") || die "Error: Can't pipe to tabulate.pl: $!\n";
foreach my $epoch (sort {$a<=>$b} keys %db) {
  print OUT @{$db{$epoch}};
}

## my %db;
## while (<IN>) {
##   if (/^\s*\S+\s+(\d+)\/(\d+)\/(\d+)\s+/) {
##     my ($month,$day,$year) = ($1,$2,$3);
##     $month--;
##     my $epoch = timelocal(0,0,16,$day,$month,$year);
##     if (exists $db{$epoch}{$_}) {
##       $db{$epoch}{$_}++;
##     } else {
##       $db{$epoch}{$_} = 1;
##     }
##   }
## }
## 
## open(OUT,"|tabulate.pl") || die "Error: Can't pipe to tabulate.pl: $!\n";
## foreach my $epoch (sort {$a<=>$b} keys %db) {
##   foreach my $key (sort keys %{$db{$epoch}}) {
##     for (my $i=0; $i<$db{$epoch}{$key}; $i++) {
##       print OUT $key;
##     }
##   }
## }
