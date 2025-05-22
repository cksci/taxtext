#!/usr/bin/env perl
use warnings;
use strict;
use Time::Local;
use File::Basename;
my $dir = dirname($0);

my %OPT;
use Getopt::Long;
GetOptions(\%OPT,"account=s");

use FindBin;
use lib "$FindBin::Bin/../lib";
use Tax::Txt;

my $USAGE = "$0 <portfolio text> ...\n";
die $USAGE unless (@ARGV > 0);

my $total_notional = 0;
my $total_cost     = 0;
my $total_price    = 0;

open(OUT,"|$dir/tt_tab.pl -right -box") || die "Error: Can't pipe to '$dir/tt_tab.pl': $!\n";
print OUT "TICKER EXPIRY NOTIONAL COST PRICE COST_PCT VALUE_PCT CHANGE_PCT ACCOUNT\n";

foreach my $file (@ARGV) {
  open(IN,$file) || die "Error: Can't read file '$file': $!\n";

  my %cols;

  while (<IN>) {

    if (/^\s*HEADER/) {
      %cols = tt_parse_header($_);

    } elsif (/^\s*HOLD/i) {

      die "Error: Didn't find header before HOLD lines!\n" if (scalar keys %cols == 0);

      my @bits = split;
      
      my $account      = $bits[$cols{ACCOUNT}];
      my $symbol       = $bits[$cols{SYMBOL}];
      my $symbol_yahoo = $bits[$cols{SYMBOL_YAHOO}];
      my $curr         = $bits[$cols{CURRENCY}];
      my $status       = $bits[$cols{STATUS}];
      my $risk         = $bits[$cols{RISK}];
      my $sector       = $bits[$cols{SECTOR}];
      my $type         = $bits[$cols{TYPE}];
      my $qty          = $bits[$cols{QUANTITY}];
      my $cost         = $bits[$cols{COST}];
      my $price        = $bits[$cols{PRICE}];
      my $change       = $bits[$cols{CHANGE}];
      my $gain_pct     = $bits[$cols{GAIN_PCT}];
      my $div          = $bits[$cols{DIV}];
      my $yield        = $bits[$cols{YIELD}];
      my $div_tot      = $bits[$cols{DIV_TOT}];
      my $div_tot_cad  = $bits[$cols{DIV_TOT_CAD}];
      my $book         = $bits[$cols{BOOK}];
      my $value        = $bits[$cols{VALUE}];
      my $gain         = $bits[$cols{GAIN}];
      my $book_cad     = $bits[$cols{BOOK_CAD}];
      my $value_cad    = $bits[$cols{VALUE_CAD}];
      my $gain_cad     = $bits[$cols{GAIN_CAD}];

      if (!exists $OPT{account} || (exists $OPT{account} && $OPT{account} eq $account)) {
        if (tt_is_option($symbol)) {
          my ($ticker,$year,$month,$day,$putcall,$strike) = tt_option_parse($symbol);

          if ($putcall =~ /p/i) {
            if ($qty < 0) {

              my $notional = abs($qty)*$strike;
              $total_notional += $notional;

              my $cost_tmp = abs($qty)*$cost;
              $total_cost += $cost_tmp;

              my $price_tmp = abs($qty)*$price;
              $total_price += $price_tmp;

              my $cost_pct = sprintf("%.2f",100*$cost/$strike);
              my $price_pct = sprintf("%.2f",100*$price/$strike);

              my $pct_change = sprintf("%.2f",$price_pct-$cost_pct);

              $notional  = fmt_money2($notional,0);
              $cost_tmp  = fmt_money2($cost_tmp,0);
              $price_tmp = fmt_money2($price_tmp,0);

              print OUT "$ticker ${year}${month}${day} $notional $cost_tmp $price_tmp $cost_pct% $price_pct% $pct_change%  $account\n";
            }
          }
        }
      }
    }
  }
}
my $total_cost_pct  = sprintf("%.2f",100*$total_cost/$total_notional);
my $total_price_pct = sprintf("%.2f",100*$total_price/$total_notional);

my $pct_change = sprintf("%.2f",$total_price_pct-$total_cost_pct);

$total_notional = fmt_money2($total_notional,0);
$total_cost     = fmt_money2($total_cost,0);
$total_price    = fmt_money2($total_price,0);

print OUT "TOTAL - $total_notional $total_cost $total_price $total_cost_pct% $total_price_pct% $pct_change% -\n";
close(OUT);
print "\n";
