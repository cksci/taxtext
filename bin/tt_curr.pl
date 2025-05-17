#!/usr/bin/env perl
use warnings;
use strict;

use File::Basename;
use FindBin;
use lib "$FindBin::Bin/../lib";
use Tax::Txt;

my $USAGE = "$0 <tt> <tt usdcad>\n";
die $USAGE unless (@ARGV == 2);

my $usdcad = pop(@ARGV);
open(IN,$usdcad) || die "Error: Can't read file '$usdcad': $!\n";

my %usdcad;
while (<IN>) {
  if (/^(\S+)\s+(\S+)/) {
    $usdcad{$1} = $2;
  }
}

my @fhs;
if (@ARGV) {
  foreach my $file (@ARGV) {
    open my $fh, '<', $file or die "Could not open '$file': $!";
    push @fhs, $fh;
  }
} else {
  push @fhs, *STDIN;
}

open(OUT,"|tabulate.pl -r") || die "Error: Can't pipe to tabulate.pl: $!\n";

foreach my $fh (@fhs) {
  my %cols;

  use POSIX qw(strftime);
  my ($sec, $min, $hour, $mday, $mon, $year) = localtime();
  $mon  += 1;        # months are 0–11
  $year += 1900;     # years since 1900
  my $date = "$mon/$mday/$year";

  while (<$fh>) {
    chomp;
    s/^\s+//;
    s/\s+$//;

    if (/^\s*HEADER/) {
      %cols = tt_parse_header($_);
      print OUT "$_\n";
      next;
    }

    if (/^\s*CASH/i) {
      my @bits = split;

      die "Error: Didn't find header before CASH lines!\n" if (scalar keys %cols == 0);

      my $account  = $bits[$cols{ACCOUNT}];
      my $currency = $bits[$cols{CURRENCY}];
      my $value    = $bits[$cols{VALUE}];

      if ($currency eq "USD") {
        my $usdcad;
        if (exists $usdcad{$date}) {
          $usdcad = $usdcad{$date};
        } else {
          warn "# Warning: No USDCAD for date '$date'\n";
          next;
        }
        my $value_cad = fmt_money($usdcad*$value,2);
        print OUT "CASH $account $currency $value $value_cad\n";
      } else {
        print OUT "CASH $account $currency $value $value\n";
      }

    } elsif (/^\s*(BUYSELL|COST)/i) {
      my @bits = split;

      my $currency = $bits[5];
      if ($currency =~ /USD/) {

        my $what        = $bits[0];
        my $date        = $bits[1];
        my $date_settle = $bits[2];
        my $symbol      = $bits[3];
        my $quantity    = $bits[4];
        my $currency    = $bits[5];
        my $price       = $bits[6];
        my $fee         = $bits[7];
        my $value       = $bits[8];

        # Note: Use the USDCAD on the settlement date
        my $usdcad;
        if (exists $usdcad{$date_settle}) {
          $usdcad = $usdcad{$date_settle};
        } else {
          warn "# Warning: No USDCAD for date '$date_settle'\n";
          next;
        }

        my $price_cad = fmt_money($usdcad*$price);
        my $fee_cad   = fmt_money($usdcad*$fee);
        my $value_cad = fmt_money($usdcad*$value);
        print OUT "$what $date $date_settle $symbol $quantity CAD $price_cad $fee_cad $value_cad\n";

      } else {
        print OUT "$_\n";
      }

    } elsif (/^\s*(INTEREST|DEPOSIT|WITHDRAWAL)/) {
      my @bits = split;
      
      my $what        = $bits[0];
      my $date        = $bits[1];
      my $date_settle = $bits[2];
      my $currency    = $bits[3];
      my $value       = $bits[4];

      if ($currency =~ /USD/) {
        my $usdcad;
        if (exists $usdcad{$date}) {
          $usdcad = $usdcad{$date};
        } else {
          warn "# Warning: No USDCAD for date '$date'\n";
          next;
        }

        my $value_cad = fmt_money($usdcad*$value);
        print OUT "$what $date $date_settle CAD $value_cad\n";

      } else {
        print OUT "$_\n";
      }

    } elsif (/^\s*DIVIDEND/) {
      my @bits = split;

      my $currency = $bits[5];
      if ($currency =~ /USD/) {

        my $what        = $bits[0];
        my $date        = $bits[1];
        my $date_settle = $bits[2];
        my $symbol      = $bits[3];
        my $quantity    = $bits[4];
        my $div_ps      = $bits[6];
        my $wh_ps       = $bits[7];
        my $value       = $bits[8];
        my $div_tot     = $bits[9];

        my $usdcad;
        if (exists $usdcad{$date}) {
          $usdcad = $usdcad{$date};
        } else {
          warn "# Warning: No USDCAD for date '$date'\n";
          next;
        }

        my $div_ps_cad  = fmt_money($div_ps*$usdcad);
        my $wh_ps_cad   = fmt_money($wh_ps*$usdcad);
        my $value_cad   = fmt_money($value*$usdcad);
        my $div_tot_cad = fmt_money($div_tot*$usdcad);
        print OUT "$what $date $date_settle $symbol $quantity CAD $div_ps_cad $wh_ps_cad $value_cad $div_tot\n";

      } else {
        print OUT "$_\n";
      }

    } else {
      print OUT "$_\n";
    }
  }
}
