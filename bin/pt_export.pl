#!/usr/bin/env perl
use warnings;
use strict;

my %OPT;
use Getopt::Long;
GetOptions(\%OPT,"sa","tv","options","options_only");
$OPT{sa} = 1 unless (exists $OPT{tv});

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

my %db;

if (exists $OPT{sa}) {
  print "Ticker,Shares,Cost,Date\n";
}
foreach my $fh (@fhs) {
  while (<$fh>) {
    if (/^\s*HOLD\s+\S+\s+\S+\s+\S+\s+\S+\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)/i) {
      my ($symbol,$curr,$qty,$cost) = ($1,$2,$3,$4);

      if ($symbol =~ /(\w+)\d\d\d\d\d\d(C|P)(\d\d\d\d\d\d\d\d)/) {
        my ($symbol2,$cp,$strike) = ($1,$2,$3);
        my $ext = "";
        $ext = $1 if ($symbol =~ /(\.\w+)$/);
        $symbol = "${symbol2}$ext";
        $cost = sprintf("%.2f",$strike/1000);

        next unless (exists $OPT{options} || exists $OPT{options_only});
        next if (exists $OPT{options});
      } else {
        next if (exists $OPT{options_only});
      }

      $qty = sprintf("%.0f",$qty);
      #next unless ($qty > 0);
      
      $symbol =~ s/\.(TO|NE)/:CA/;
      $symbol =~ s/-P(\w)/.PR.$1/g;

      #next if (exists $db{$symbol});
      #$db{$symbol} = 1;

      if (exists $OPT{sa}) {
        print "$symbol,$qty,$cost,$date\n";
      } elsif (exists $OPT{tv}) {
        if ($symbol =~ s/:CA//) {
          $symbol = "TSX:$symbol";
        }
        print "$symbol\n";
      }
    }
  }
}
