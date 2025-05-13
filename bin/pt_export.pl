#!/usr/bin/env perl
use warnings;
use strict;

my %OPT;
use Getopt::Long;
GetOptions(\%OPT,"sa","tv","fg","options_too","options_only");
$OPT{sa} = 1 unless (exists $OPT{tv} || exists $OPT{fg});

my $num = 0;
$num++ if (exists $OPT{sa});
$num++ if (exists $OPT{tv});
$num++ if (exists $OPT{fg});
die "Error: Specify only one of -sa, -tv, -fg!\n" if ($num > 1);

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

if (exists $OPT{sa}) {
  print "Ticker,Shares,Cost,Date\n";
} elsif (exists $OPT{fg}) {
  print "ticker,date,type,shares,per_share,total,currency\n";
}

my @fg;
my %db;

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

        next unless (exists $OPT{options_too} || exists $OPT{options_only});

      } else {

        next if (exists $OPT{options_only});
      }

      $qty = sprintf("%.0f",$qty);
      #next unless ($qty > 0);
      
      $symbol =~ s/\.(TO|NE)/:CA/;
      $symbol =~ s/-P(\w)/.PR.$1/g;
      $symbol = "$symbol:US" unless ($symbol =~ /\:\w+$/);

      if (exists $OPT{fg}) {
        $symbol =~ s/-UN/.UT/g; # Ex. NXR-UN.TO -> NXR.UT:CA
      }

      next if (exists $db{$symbol});
      $db{$symbol} = 1;

      if (exists $OPT{sa}) {
        print "$symbol,$qty,$cost,$date\n";

      } elsif (exists $OPT{fg}) {
        #print "$symbol,$date,by,$qty,$cost,$curr\n";
        push @fg,$symbol;

      } elsif (exists $OPT{tv}) {
        if ($symbol =~ s/:CA//) {
          $symbol = "TSX:$symbol";
        }
        print "$symbol\n";
      }
    }
  }
}
print join(",",@fg) . "\n";
