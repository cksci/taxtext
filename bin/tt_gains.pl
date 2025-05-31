#!/usr/bin/env perl
use warnings;
use strict;
use Time::Local;
use File::Basename;
my $dir = dirname($0);

my %OPT;
use Getopt::Long;
GetOptions(\%OPT,"year=s","quiet");

use File::Basename;
use FindBin;
use lib "$FindBin::Bin/../lib";
use Tax::Txt;

my @fhs;
if (@ARGV) {
  foreach my $file (@ARGV) {
    open my $fh, '<', $file or die "Could not open '$file': $!";
    push @fhs, $fh;
  }
} else {
  push @fhs, *STDIN;
}

open(OUT,"|$dir/tt_tab.pl") || die "Error: Can't pipe to '$dir/tt_tab.pl': $!\n";

my %db;
my %last_gain;

my $zero = fmt_money(0.0);

my %tot_gain;
my %tot_options_gain;
my %tot_div;

foreach my $fh (@fhs) {
  while (<$fh>) {
    s/#.*//g;

    if (/^\s*(BUYSELL|COST)/i) {
      my @bits = split;

      my $what        = $bits[0];
      my $date        = $bits[1];
      my $date_settle = $bits[2];
      my $symbol      = $bits[3];
      my $quantity    = $bits[4];
      my $currency    = $bits[5];
      my $price       = $bits[6];
      my $fee         = $bits[7];
      my $value       = $bits[8];

      my $symbol_curr = "N/A";
      if ($symbol =~ /(\.|\-|\/)(USD|CAD|MXN|GBP)$/) {
        $symbol_curr = $2;
      } else {
        die "Error: Can't determine currency of symbol '$symbol'\n";
      }

      $symbol =~ s/^DLR\.\w+/DLR/; # Nuke currency for DLR.CAD and DLR.USD to handle journaling

      my $print = 1;
      if (exists $OPT{year}) {
        my $year = get_date_year($date_settle); ;# Note settle date is used in Canada to determine capital gain tax year
        $print = 0 if ($year ne $OPT{year});
      }

      my $epoch_seconds;
      my $epoch_days;
      if ($date_settle =~ /^(\d+)\/(\d+)\/(\d+)$/i) {
        my ($month,$day,$year) = ($1,$2,$3);
        $epoch_seconds = timelocal(0, 0, 0, $day, $month - 1, $year - 1900);
        $epoch_days = $epoch_seconds/86400;
      } else {
        die;
      }

      # Buy order
      if ($quantity > 0) {
        
        my $average_price = fmt_money($price+$fee/$quantity);

        if (exists $db{$symbol}) {

          my $quantity_old      = $db{$symbol}{quantity};
          my $quantity_new      = $quantity_old+$quantity;
          my $average_price_old = $db{$symbol}{average_price};

          # Case 2: Buy when having a short position
          if ($quantity_old < 0) {

            $db{$symbol}{quantity} = $quantity_new;
            push @{$db{$symbol}{transact}}, $_;

            my $price_delta = fmt_money($average_price_old-$average_price);
            my $gain        = fmt_money($quantity*$price_delta);

            my $cost        = fmt_money(abs($quantity)*$average_price_old);
            my $market      = fmt_money(abs($quantity)*$average_price);

            if ($print) {
              print OUT "GAIN $date $date_settle $symbol $quantity $currency $average_price_old $average_price $price_delta $market $cost $gain $quantity_new\n"; # Note flip of market/cost
              $tot_gain{$symbol_curr} = 0 unless (exists $tot_gain{$symbol_curr});
              $tot_gain{$symbol_curr} += $gain;

              if (tt_is_option($symbol)) {
                $tot_options_gain{$symbol_curr} = 0 unless (exists $tot_options_gain{$symbol_curr});
                $tot_options_gain{$symbol_curr} += $gain;
              }
            }

          # Case 3: Buy when having a long position
          } else {

            my $average_price_new = fmt_money(($quantity_old/$quantity_new)*$average_price_old + ($quantity/$quantity_new)*$average_price);

            $db{$symbol}{quantity}      = $quantity_new;
            $db{$symbol}{average_price} = $average_price_new;
            push @{$db{$symbol}{transact}}, $_;

            if (exists $last_gain{$symbol}{sell_days_epoch}) {
              my $delta_days = $epoch_days - $last_gain{$symbol}{sell_days_epoch};
              if ($delta_days < 30) {
                if ($last_gain{$symbol}{gain} < 0) {
                  warn "# Warning: Possible existing position superficial loss on $date_settle with add of $quantity of symbol $symbol at price $price, $last_gain{$symbol}{quantity} of which were previously sold within 30 calendar days on $last_gain{$symbol}{date_sell} at loss of $last_gain{$symbol}{gain} and average cost $last_gain{$symbol}{average_price}\n";
                }
              }
            }
          }

          # Delete data if position is totally closed
          if (abs($quantity_new) < 1e-6) {
            delete $db{$symbol};
          }

        # Case 1: Buy when no existing shares
        } else {

          $db{$symbol}{quantity}      = $quantity;
          $db{$symbol}{average_price} = $average_price;
          push @{$db{$symbol}{transact}}, $_;

          if (exists $last_gain{$symbol}{sell_days_epoch}) {
            my $delta_days = $epoch_days - $last_gain{$symbol}{sell_days_epoch};
            if ($delta_days < 30) {
              if ($last_gain{$symbol}{gain} < 0) {
                warn "# Warning: Possible new position superficial loss on $date_settle with add of $quantity of symbol $symbol at price $price, $last_gain{$symbol}{quantity} of which were previously sold within 30 calendar days on $last_gain{$symbol}{date_sell} at loss of $last_gain{$symbol}{gain} and average cost $last_gain{$symbol}{average_price}\n";
              }
            }
          }
        }

      # Sell
      } else {

        my $average_price = fmt_money($price+$fee/$quantity);

        if (exists $db{$symbol}) {

          my $quantity_old      = $db{$symbol}{quantity};
          my $quantity_new      = $quantity_old+$quantity;
          my $average_price_old = $db{$symbol}{average_price};

          # Case 2: Sell when having a short position
          if ($quantity_old < 0) {

            my $average_price_new = fmt_money(($quantity_old/$quantity_new)*$average_price_old + ($quantity/$quantity_new)*$average_price);

            $db{$symbol}{quantity}      = $quantity_new;
            $db{$symbol}{average_price} = $average_price_new;
            push @{$db{$symbol}{transact}}, $_;

          # Case 3: Sell when having a long position
          } else {

            $db{$symbol}{quantity} = $quantity_new;
            push @{$db{$symbol}{transact}}, $_;

            my $price_delta = fmt_money($average_price-$average_price_old);
            my $gain        = fmt_money(abs($quantity)*$price_delta);

            my $cost        = fmt_money(abs($quantity)*$average_price_old);
            my $market      = fmt_money(abs($quantity)*$average_price);

            if ($print) {
              print OUT "GAIN $date $date_settle $symbol $quantity $currency $average_price_old $average_price $price_delta $cost $market $gain $quantity_new\n"; 
              $tot_gain{$symbol_curr} = 0 unless (exists $tot_gain{$symbol_curr});
              $tot_gain{$symbol_curr} += $gain;

              if (tt_is_option($symbol)) {
                $tot_options_gain{$symbol_curr} = 0 unless (exists $tot_options_gain{$symbol_curr});
                $tot_options_gain{$symbol_curr} += $gain;
              }
            }

            $last_gain{$symbol}{sell_days_epoch} = $epoch_days;
            $last_gain{$symbol}{date_sell} = $date_settle;
            $last_gain{$symbol}{gain}      = $gain;
            $last_gain{$symbol}{cost}      = $cost;
            $last_gain{$symbol}{quantity}  = $quantity;
            $last_gain{$symbol}{average_price} = $average_price_old;
          
          }

          # Delete data if position is totally closed
          if (abs($quantity_new) < 1e-6) {
            delete $db{$symbol};
          }

        # Case 1: Sell (short) when no existing shares
        } else {

          $db{$symbol}{quantity}      = $quantity;
          $db{$symbol}{average_price} = $average_price;
          push @{$db{$symbol}{transact}}, $_;
        }
      }
    } elsif (/^\s*DIVIDEND/i) {
      my @bits = split;

      my $what        = $bits[0];
      my $date        = $bits[1];
      my $date_settle = $bits[2];
      my $symbol      = $bits[3];
      my $quantity    = $bits[4];
      my $currency    = $bits[5];
      my $div_ps      = $bits[6];
      my $wh          = $bits[7];
      my $value       = $bits[8];
      my $div_tot     = $bits[9];

      my $symbol_curr = "N/A";
      if ($symbol =~ /\.(USD|CAD|MXN)/) {
        $symbol_curr = $1;
      }

      my $print = 1;
      if (exists $OPT{year}) {
        my $year = get_date_year($date); ;# Note pay date is used in Canada to determine dividend tax year
        $print = 0 if ($year ne $OPT{year});
      }

      if ($print) {
        $tot_div{$symbol_curr} = 0 unless (exists $tot_div{$symbol_curr});
        $tot_div{$symbol_curr} += $div_tot;
      }

    } elsif (/^\s*ADJUSTQ\s+/i) {
      my @bits = split;

      my $what        = $bits[0];
      my $date        = $bits[1];
      my $date_settle = $bits[2];
      my $symbol      = $bits[3];
      my $quantity    = $bits[4];
      my $currency    = $bits[5];

      if (exists $db{$symbol}) {
        my $quantity_old            = $db{$symbol}{quantity};
        my $factor                  = $quantity/$quantity_old;
        $db{$symbol}{quantity}      = $quantity;
        my $tmp = $db{$symbol}{average_price};
        $db{$symbol}{average_price} = fmt_money($db{$symbol}{average_price}/$factor);
        push @{$db{$symbol}{transact}}, $_;

        warn "# Warning: ADJUSTQ $symbol cost basis from $tmp by $factor to $db{$symbol}{average_price}\n";
      } else {
        warn "Error: Found stock quantity adjust for symbol '$symbol' at date '$date' but no position exists\n";
      }

    } elsif (/^\s*SPLIT\s+/i) {
      my @bits = split;

      my $what        = $bits[0];
      my $date        = $bits[1];
      my $date_settle = $bits[2];
      my $symbol      = $bits[3];
      my $factor      = $bits[4];
      my $currency    = $bits[5];

      if (exists $db{$symbol}) {
        $db{$symbol}{quantity}      = sprintf("%.3f",$factor*$db{$symbol}{quantity});
        $db{$symbol}{average_price} = fmt_money($db{$symbol}{average_price}/$factor);
        push @{$db{$symbol}{transact}}, $_;

      } else {
        warn "Error: Found stock split for symbol '$symbol' at date '$date' but no position exists\n";
      }
    }
  }
}

my ($sec, $min, $hour, $mday, $mon, $year) = localtime();
$mon  += 1;
$year += 1900;
my $date = "$mon/$mday/$year";

print OUT "\n";

foreach my $symbol (sort keys %db) {
  foreach my $line (@{$db{$symbol}{transact}}) {
    chomp $line;
    print OUT "$line #$db{$symbol}{quantity}\n";
  }

  my $cost = fmt_money(abs($db{$symbol}{quantity})*$db{$symbol}{average_price});
  
  my $curr;
  if ($symbol =~ /(\.|\-|\/)(\w+)$/) {
    $curr = $2;
  } else {
    warn "# Warning: Couldn't determine currency of symbol '$symbol'\n";
    next;
  }

  print OUT "COST $date $date $symbol $db{$symbol}{quantity} $curr $db{$symbol}{average_price} $zero $cost\n"; 
}

unless (exists $OPT{quiet}) {
  my $tot_gain = 0;
  foreach my $curr (sort keys %tot_gain) {
    warn "# Info: Total Realized $curr Gain is " . fmt_money2($tot_gain{$curr},2) . "\n";
    $tot_gain += $tot_gain{$curr};
  }
  warn "# Info: Total Realized Gain is " . fmt_money2($tot_gain,2) . "\n";
  warn "\n";

  my $tot_options_gain = 0;
  foreach my $curr (sort keys %tot_options_gain) {
    warn "# Info: Total Realized $curr Options Gain is " . fmt_money2($tot_options_gain{$curr},2) . "\n";
    $tot_options_gain += $tot_options_gain{$curr};
  }
  warn "# Info: Total Realized Option Gain is " . fmt_money2($tot_options_gain,2) . "\n";
  warn "\n";

  my $tot_div = 0;
  foreach my $curr (sort keys %tot_div) {
    warn "# Info: Total Realized $curr Dividend Gain is " . fmt_money2($tot_div{$curr},2) . "\n";
    $tot_div += $tot_div{$curr};
  }
  warn "# Info: Total Realized Dividend is " . fmt_money2($tot_div,2) . "\n";
  warn "\n";
}
