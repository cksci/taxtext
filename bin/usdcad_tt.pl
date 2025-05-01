#!/usr/bin/env perl
use warnings;
use strict;

use File::Basename;
use FindBin;
use lib "$FindBin::Bin/../lib";
use Tax::Txt;

my $USAGE = "$0 <USDCAD Yahoo>\n";
die $USAGE unless (@ARGV == 1);

my $file = $ARGV[0];
open(IN,$file) || die "Error: Can't read file '$file': $!\n";
open(OUT,"|tabulate.pl") || die "Error: Can't pipe to tabulate.pl: $!\n";

my %usdcad;
while (<IN>) {
  if (/^\s*\"(\d+)\/(\d+)\/(\d+)\",\"([\d\.]+)\"/) {
    my ($month,$day,$year,$value) = ($1,$2,$3,$4);
    $month =~ s/^0//g;
    $day =~ s/^0//g;
    print OUT "$month/$day/$year $value\n";
  }
}
