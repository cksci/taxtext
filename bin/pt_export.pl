#!/usr/bin/env perl
use warnings;
use strict;

my %OPT;
use Getopt::Long;
GetOptions(\%OPT,"sa","tv","fg","options_too","options_only");
$OPT{sa} = 1 unless (exists $OPT{tv} || exists $OPT{fg});

use FindBin;
use lib "$FindBin::Bin/../lib";
use Tax::Txt;

my $num = 0;
$num++ if (exists $OPT{sa});
$num++ if (exists $OPT{tv});
$num++ if (exists $OPT{fg});
die "Error: Specify only one of -sa, -tv, -fg!\n" if ($num > 1);

my $USAGE = "$0 [-sa|-fg|-tv] <pt text> ...\n";
die $USAGE unless (@ARGV > 0);

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
  my %cols;

  while (<$fh>) {
    s/^\s+//;
    s/\s+$//;

    if (/^\s*HEADER/) {
      %cols = tt_parse_header($_);
    }

    if (/^\s*HOLD/) {

      die "Error: Didn't find header before HOLD lines!\n" if (scalar keys %cols == 0);

      my @bits   = split;
      my $symbol = $bits[$cols{SYMBOL}];
      my $curr   = $bits[$cols{CURRENCY}];
      my $qty    = $bits[$cols{QUANTITY}];
      my $cost   = $bits[$cols{COST}];
      my $type   = $bits[$cols{TYPE}];

      if ($symbol =~ /(\w+)\d\d\d\d\d\d(C|P)(\d\d\d\d\d\d\d\d)/) {

        my ($underlying,$cp,$strike) = ($1,$2,$3);
        my $ext = "";
        $ext = $1 if ($symbol =~ /(\.\w+)$/);
        $symbol = "${underlying}$ext";
        $cost = sprintf("%.2f",$strike/1000);

        next unless (exists $OPT{options_too} || exists $OPT{options_only});

      } else {
        next if (exists $OPT{options_only});
      }

      $qty = sprintf("%.0f",abs($qty));
      
      $symbol =~ s/\.CAD$/:CA/;
      $symbol =~ s/\.USD$/:US/;

      if (exists $OPT{fg}) {
        $symbol =~ s/\.UN/.UT/g; # Ex. NXR.UN.CAD -> NXR.UT:CA
      }

      next if (exists $db{$symbol});
      $db{$symbol} = 1;

      if (exists $OPT{sa}) {
        print "$symbol,$qty,$cost,$date\n";

      } elsif (exists $OPT{fg}) {
        next if ($type =~ /ETF|CRYPTO/i);
        next if ($symbol =~ /\.PR\./);
        push @fg,$symbol;

      } elsif (exists $OPT{tv}) {
        $symbol =~ s/\:US$//;
        if ($symbol =~ s/:CA//) {
          $symbol = "TSX:$symbol";
        }
        print "$symbol\n";
      }
    }
  }
}
if (exists $OPT{fg}) {
  print join(",",@fg) . "\n";
}
