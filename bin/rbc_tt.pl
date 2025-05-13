#!/usr/bin/env perl
use warnings;
use strict;

use File::Basename;
use FindBin;
use lib "$FindBin::Bin/../lib";
use Tax::Txt;

my $USAGE = "$0 <RBC Activity csv> ...\n";
die $USAGE unless (@ARGV > 0);

# TODO: Date order should be auto-detected not assumed
open(OUT,"|reverse.pl|tabulate.pl") || die "Error: Can't pipe to tabulate.pl: $!\n";

foreach my $file (@ARGV) {
  open(IN,$file) || die "Error: Can't read file '$file': $!\n";

  my %cols;
  while (<IN>) {
    chomp;
    if (/^\s*\"Date\"/) {
      s/\"//g;
      my @bits = split(/,/);
      for (my $i=0; $i<@bits; $i++) {
        $cols{$bits[$i]} = $i;
      }
      last;
    }
  }

  while (<IN>) {
    chomp;
    last if (/^\s*$/);
    s/^\s*\"|\"\s*$//g;

    my @bits = split(/\"\s*,\s*\"/);

    my $date        = convert_date($bits[$cols{"Date"}]);
    my $date_settle = convert_date($bits[$cols{"Settlement Date"}]);

    my $activity    = $bits[$cols{"Activity"}];
    my $symbol      = $bits[$cols{"Symbol"}];
    my $quantity    = $bits[$cols{"Quantity"}];
    my $price       = $bits[$cols{"Price"}];
    my $currency    = $bits[$cols{"Currency"}];
    my $value_sign  = fmt_money($bits[$cols{"Value"}]);
    my $value       = fmt_money(abs($bits[$cols{"Value"}]));
    my $desc        = $bits[$cols{"Description"}];
    my $symbol_desc = $bits[$cols{"Symbol Description"}];

    my $zero = fmt_money(0.0);
    my $is_option = 0;

    if ($symbol_desc =~ /(CALL|PUT)\s+\.?(\w+)\s+(\d+)\/(\d+)\/(\d+)\s+([\d\.]+)/i) {
      my ($what,$symbol_tmp,$month_tmp,$day_tmp,$year_tmp,$strike) = ($1,$2,$3,$4,$5,$6);
      $strike = sprintf("%08d",1000*$strike);
      #$what =~ s/^(\w).+/$1/;
      $what =~ tr/a-z/A-Z/;
      $symbol = "${symbol_tmp}${year_tmp}${month_tmp}${day_tmp}${what}${strike}";
      $is_option = 1;
    }

    if (defined $desc && $desc =~ /(CALL|PUT)\s+\.?(\w+)\s+(\d+)\/(\d+)\/(\d+)\s+([\d\.]+)/i) {
      my ($what,$symbol_tmp,$month_tmp,$day_tmp,$year_tmp,$strike) = ($1,$2,$3,$4,$5,$6);
      $strike = sprintf("%08d",1000*$strike);
      #$what =~ s/^(\w).+/$1/;
      $what =~ tr/a-z/A-Z/;
      $symbol = "${symbol_tmp}${year_tmp}${month_tmp}${day_tmp}${what}${strike}";
      $is_option = 1;
    }

    if (defined $quantity && $quantity ne "" && $is_option) {
      $quantity *= 100.0;
    }

    if ($activity =~ /buy/i) {
      my $fee = calc_fee($value,$price,$quantity);
      print OUT "BUYSELL $date $date_settle $symbol.$currency $quantity $currency $price $fee $value\n";

    } elsif ($activity =~ /other/i) {
      if ($desc =~ /retraction.*\$\s*([\d\.]+)\/share/i) {
        $price = $1;
      } elsif ($desc =~ /retraction.*\$\s*([\d\.]+)\s+per\s+share/i) {
        $price = $1;
      } elsif ($desc =~ /ASN\s+\-\s+CALL/i) {
        $price = $zero;
      } else {
        warn "Warning: Couldn't determine retraction price for following line:\n  $_\n";
        next;
      }

      my $fee = calc_fee($value,$price,$quantity);
      print OUT "BUYSELL $date $date_settle $symbol.$currency $quantity $currency $price $fee $value\n";

    } elsif ($activity =~ /sell/i) {
      my $fee = calc_fee($value,$price,$quantity);
      print OUT "BUYSELL $date $date_settle $symbol.$currency $quantity $currency $price $fee $value\n";
    
    } elsif ($activity =~ /^deposits\s+/i) {
      print OUT "DEPOSIT $date $date_settle $currency $value\n"

    } elsif ($activity =~ /^withdrawals\s+/i) {
      print OUT "WITHDRAWAL $date $date_settle $currency $value\n"

    } elsif ($activity =~ /interest/i) {
      print OUT "INTEREST $date $date_settle $currency $value_sign\n";  # Note sign

    } elsif ($activity =~ /dividend|distribution/i) {

      my $shares;
      if ($desc =~ /\s(\d+)\s+SHS/) {
        $shares = $1;
      } elsif (defined $quantity && $quantity ne "") {
        $shares = $quantity;
        # TODO: Check when this happens"
      } else {
        warn "Error: DEBUG ME!!\n";
        next;
      }

      # There is an endcase where a negative dividend is paid when it had been given originally in error
      if ($value_sign < 0) {
        $shares *= -1;
        $value = fmt_money(-1*$value);
      }

      # Check if any witholding tax mentioned
      my $wh = 0;
      $wh = 1 if ($desc =~ /NON\-RES\s+TAX/i);

      # TODO: Update for specific stocks
      my $WH_TAX_RATE = 0.15;
      if ($symbol =~ /^(GFI|HMY)$/i) {
        $WH_TAX_RATE = 0.2;
      } elsif ($symbol =~ /^(TSM)$/i) {
        $WH_TAX_RATE = 0.21;
      } elsif ($symbol =~ /^(LVMUY|TT|ITRN)$/i) {
        $WH_TAX_RATE = 0.25;
      }

      if ($wh) {
        my $div_tot = fmt_money($value/(1-$WH_TAX_RATE));
        my $div_ps = fmt_money($div_tot/$shares);
        my $wh     = fmt_money($div_tot*$WH_TAX_RATE);
        print OUT "DIVIDEND $date $date_settle $symbol.$currency $shares $currency $div_ps $wh $value $div_tot\n";

      } else {
        my $div_ps = fmt_money($value/$shares);
        print OUT "DIVIDEND $date $date_settle $symbol.$currency $shares $currency $div_ps $zero $value $value\n";
      }

    } elsif ($activity =~ /reorganization/i) {

      if ($desc =~ /OPTION\s+EXPIRATION/i) {
        print OUT "BUYSELL $date $date_settle $symbol.$currency $quantity $currency $zero $zero $value\n"; # Note: No fee for expiry

      } elsif ($desc =~ /STK\s+SPLIT\s+ON\s+(\d+)/) {

        my $quantity_split = $1;
        my $quantity_new   = $quantity+$quantity_split;
        my $split_ratio    = sprintf("%.3f",$quantity_new/$quantity_split);
        print OUT "SPLIT $date $date_settle $symbol.$currency $split_ratio $currency\n";

      } elsif ($desc =~ /MGR\s+\-/ || $desc =~ /REV.*REVERSE\s+SPLIT/i) {
        # TODO: Review each line that ends up here
        if ($quantity > 0) {
          print OUT "ADJUSTQ $date $date_settle $symbol.$currency $quantity $currency\n";
        } else {
          warn "Warning: Ignoring ADJUSTQ on line: $_\n";
        }
      } elsif ($desc =~ /(INTEREST|STOCK)\s+SPINOFF/) {
        print OUT "BUYSELL $date $date_settle $symbol.$currency $quantity $currency $zero $zero $zero\n"; # Note: No fee for expiry
      }

    } elsif ($activity =~ /transfer|taxes|fees/i) {
      # Ignore
    } else {
      warn "Warning: Don't know how to parse:\n  $_\n";
    }
  }
}
