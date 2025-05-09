#!/usr/bin/env perl
use warnings;
use strict;

my @fhs;

if (@ARGV) {
  foreach my $file (@ARGV) {
    open my $fh, '<', $file or die "Could not open '$file': $!";
    push @fhs, $fh;
  }
} else {
  push @fhs, *STDIN;
}

use POSIX qw(strftime);
my $date = strftime "%Y-%m-%d", localtime;

print "Ticker,Shares,Cost,Date\n";
foreach my $fh (@fhs) {
  while (<$fh>) {
    if (/^\s*HOLD\s+\S+\s+\S+\s+\S+\s+\S+\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)/i) {
      my ($symbol,$curr,$qty,$cost) = ($1,$2,$3,$4);
      $qty = sprintf("%.0f",$qty);
      next unless ($qty > 0);
      if ($symbol =~ /(\w+)\d\d\d\d\d\d(C|P)(\d\d\d\d\d\d\d\d)/) {
        my ($symbol2,$cp,$strike) = ($1,$2,$3);
        my $ext = "";
        $ext = $1 if ($symbol =~ /(\.\w+)$/);
        $symbol = "${symbol2}$ext";
        $cost = sprintf("%.2f",$strike/1000);
      }
      
      $symbol =~ s/\.(TO|NE)/:CA/;
      $symbol =~ s/-P(\w)/.PR.$1/g;
      print "$symbol,$qty,$cost,$date\n";
    }
  }
}
