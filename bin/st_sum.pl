#!/usr/bin/env perl
use warnings;
use strict;
use Time::Local;
use File::Basename;
my $dir = dirname($0);

our %OPT;
use Getopt::Long;
GetOptions(
  \%OPT,
  "date=s",
  "date_us=s",
  "debug"
);

use FindBin;
use lib "$FindBin::Bin/../lib";
use Tax::Txt;

my $USAGE = "$0 [-date %m/%d/%y] <splitcorp text> ...\n";
die $USAGE unless (@ARGV > 0);

my $date_now = tt_get_date();
if (exists $OPT{date}) {
  $date_now = $OPT{date};
}

my $date_us_now = tt_get_date();
if (exists $OPT{date_us}) {
  $date_us_now = $OPT{date_us};
}

my ($mon_now,$day_now,$year_now);
if ($date_now =~ /(\d+)\/(\d+)\/(\d+)/) {
  ($mon_now,$day_now,$year_now) = ($1,$2,$3);
} else {
  die "Error: Unexpected date format '$date_now'\n";
}

foreach my $file (@ARGV) {
  open(IN,$file) || die "Error: Can't read file '$file': $!\n";

  my %nav;
  my %weight;

  while (<IN>) {

    chomp;
    s/#.*//g;
    s/^\s+//;
    s/\s+$//;
    s/\s+/ /g;
    s/,//g;

    if (/^NAV\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)/i) {
      my ($date,$nav,$cash_pct,$cs_ticker,$ps1_ticker,$ps2_ticker,$cs_qty,$ps1_qty,$ps2_qty,$cs_price,$ps1_price,$ps2_price,$cs_nom,$ps1_nom,$ps2_nom,$days,$mon_pct,$annual_pct,$annual_mon) = ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16,$17,$18,$19);

      $nav{$date}{nav}        = $nav;
      $nav{$date}{cash_pct}   = $cash_pct;
      $nav{$date}{cs_ticker}  = $cs_ticker;
      $nav{$date}{ps1_ticker} = $ps1_ticker;
      $nav{$date}{ps2_ticker} = $ps2_ticker;
      $nav{$date}{cs_qty}     = $cs_qty;
      $nav{$date}{ps1_qty}    = $ps1_qty;
      $nav{$date}{ps2_qty}    = $ps2_qty;
      $nav{$date}{cs_price}   = $cs_price;
      $nav{$date}{ps1_price}  = $ps1_price;
      $nav{$date}{ps2_price}  = $ps2_price;
      $nav{$date}{cs_nom}     = $cs_nom;
      $nav{$date}{ps1_nom}    = $ps1_nom;
      $nav{$date}{ps2_nom}    = $ps2_nom;
      $nav{$date}{days}       = $days;
      $nav{$date}{mon_pct}    = $mon_pct;
      $nav{$date}{annual_pct} = $annual_pct;
      $nav{$date}{annual_mon} = $annual_mon;

    } elsif (/^WEIGHT\s+(\S+)\s+(\S+)\s+(\S+)/i) {
      my ($date,$ticker,$pct) = ($1,$2,$3);
      $weight{$date}{$ticker} = $pct;
    }
  }

  ## Check weights add to 100
  foreach my $date (sort keys %weight) {
    my $total = 0;
    foreach my $ticker (keys %{$weight{$date}}) {
      $total += $weight{$date}{$ticker};
    }

    if (abs($total - 100) > 1e-3) {
      warn "Warning: Total weight for date '$date' is $total not 100 in file '$file'\n";
    }
  }

  my $date_base = tt_get_latest_date(keys %weight);
  my $date = tt_get_latest_date(keys %nav);

  my $nav        = $nav{$date}{nav};
  my $cash_pct   = $nav{$date}{cash_pct};
  my $cs_ticker  = $nav{$date}{cs_ticker};
  my $ps1_ticker = $nav{$date}{ps1_ticker};
  my $ps2_ticker = $nav{$date}{ps2_ticker};
  my $cs_qty     = $nav{$date}{cs_qty};
  my $ps1_qty    = $nav{$date}{ps1_qty};
  my $ps2_qty    = $nav{$date}{ps2_qty};
  my $cs_price   = $nav{$date}{cs_price};
  my $ps1_price  = $nav{$date}{ps1_price};
  my $ps2_price  = $nav{$date}{ps2_price};
  my $cs_nom     = $nav{$date}{cs_nom};
  my $ps1_nom    = $nav{$date}{ps1_nom};
  my $ps2_nom    = $nav{$date}{ps2_nom};
  my $days       = $nav{$date}{days};
  my $mon_pct    = $nav{$date}{mon_pct};
  my $annual_pct = $nav{$date}{annual_pct};
  my $annual_mon = $nav{$date}{annual_mon};

  # Scale equity based on new cash weight
  my $cash_weight_base   = $weight{$date_base}{CASH};
  my $equity_weight_base = 100-$cash_weight_base;

  my $cash_weight   = $cash_pct;
  my $equity_weight = 100-$cash_weight;

  my $equity_scaler = sprintf("%.5f",$equity_weight/$equity_weight_base);
  my $cash = sprintf("%.0f",$nav*$cash_weight/100.0);

  print "BASE DATE:           $date_base\n";
  print "BASE CASH WEIGHT:    $cash_weight_base\n"; 
  print "BASE EQUITY WEIGHT:  $equity_weight_base\n";
  print "MONTH DATE:          $date\n";
  print "MONTH CASH WEIGHT:   $cash_weight\n"; 
  print "MONTH EQUITY WEIGHT: $equity_weight\n";
  print "MONTH EQUITY SCALER: $equity_scaler\n";
  print "CS  TICKER:          $cs_ticker\n";
  print "PS1 TICKER:          $ps1_ticker\n";
  print "PS2 TICKER:          $ps2_ticker\n";
  print "\n";

  my ($usdcad,)     = yf_parse("USDCAD=X",$date);
  my ($usdcad_now,) = yf_parse("USDCAD=X",$date_us_now);

  my $nav_now = $cash;
  my $total_div_tot = 0;

  open(OUT, "|$dir/tt_tab.pl -right -box") || die "Error: Can't pipe to '$dir/tt_tab.pl': $!\n";
  print OUT "TICKER CURRENCY WEIGHT SHARES PRICE PRICE_NOW DIV YIELD% DIV_TOTAL NAV NAV_NOW CHANGE%\n";

  foreach my $ticker (sort keys %{$weight{$date_base}}) {

    next if ($ticker eq "CASH");
    my $curr = "USD";
    $curr = "CAD" if ($ticker =~ /\.TO$/);

    my $weight = $equity_scaler*$weight{$date_base}{$ticker};
    my $nav_ticker = $nav*($weight/100.0);

    my $price;
    my $price_now;
    my $div;
    my $div_now;
    my $shares;
    my $market_cap;
    my $market_cap_now;

    if ($ticker =~ /\.TO/) {
      ($price,$div_now) = yf_parse($ticker,$date);
      ($price_now,$div) = yf_parse($ticker,$date_now);
      $shares = sprintf("%.0f",$nav_ticker/$price);
      $market_cap = $shares*$price;
      $market_cap_now = $shares*$price_now;
    } else {
      ($price,$div_now) = yf_parse($ticker,$date);
      ($price_now,$div) = yf_parse($ticker,$date_us_now);
      $shares = sprintf("%.0f",$nav_ticker/$price/$usdcad);
      $market_cap = $shares*$price*$usdcad;
      $market_cap_now = $shares*$price_now*$usdcad_now;
    }

    my $change_pct = 100.0*($price_now/$price-1);
    my $yield_pct = 100.0*($div/$price_now);

    $nav_now += $market_cap_now;
    my $div_tot = $shares*$div;
    $total_div_tot += $div_tot;

    print OUT $ticker;
    print OUT " $curr";
    print OUT " " . fmt_money2($weight,2);
    print OUT " " . fmt_money2($shares,0);
    print OUT " " . fmt_money2($price,2);
    print OUT " " . fmt_money2($price_now,2);
    print OUT " " . fmt_money2($div,2);
    print OUT " " . fmt_money2($yield_pct,2);
    print OUT " " . fmt_money2($div_tot,0);
    print OUT " " . fmt_money2($market_cap,0);
    print OUT " " . fmt_money2($market_cap_now,0);
    print OUT " " . fmt_money2($change_pct,2);
    print OUT "\n";
  }
  close(OUT);
  print "\n";

  my $total_div_yield = 100.0*$total_div_tot/$nav_now;

  my $nav_change     = $nav_now-$nav;
  my $nav_change_pct = 100.0*($nav_now/$nav-1);

  my $unit_price = $cs_price + $ps1_price;
  if ($ps2_ticker =~ /\w/) {
    $unit_price += $ps2_price;
  }

  my ($cs_price_now,$cs_div)   = yf_parse($cs_ticker,$date_now);
  my ($ps1_price_now,$ps1_div) = yf_parse($ps1_ticker,$date_now);

  my $unit_price_now = $cs_price_now + $ps1_price_now;
  my $market_cap_now = $cs_qty*$cs_price_now + $ps1_qty*$ps1_price_now;

  my $ps2_price_now = "-";
  my $ps2_curr = "-";
  my $ps2_div = "-";

  if ($ps2_ticker =~ /\w/) {
    ($ps2_price_now,$ps2_div) = yf_parse($ps2_ticker,$date_now);
    $unit_price_now += $ps2_price_now;
    $market_cap_now += $ps2_qty*$ps2_price_now;
  }

  my $unit_price_change_pct = 100.0*($unit_price_now/$unit_price-1);

  my $cs_market_cap  = $cs_qty*$cs_price_now;
  my $ps1_market_cap = $ps1_qty*$ps1_price_now;
  my $ps2_market_cap = $ps2_qty*$ps2_price_now if ($ps2_ticker =~ /\w/);

  my $cs_price_change_pct  = 100.0*($cs_price_now/$cs_price-1);
  my $ps1_price_change_pct = 100.0*($ps1_price_now/$ps1_price-1);
  my $ps2_price_change_pct = 100.0*($ps2_price_now/$ps2_price-1) if ($ps2_ticker =~ /\w/);

  my $cs_nav_ps  = 0;
  my $ps1_nav_ps = 0;
  my $ps2_nav_ps = "-";

  if ($ps1_qty*$ps1_nom > $nav_now) {
    $ps1_nav_ps = $nav_now/$ps1_qty;

  } else {

    $ps1_nav_ps = $ps1_nom;
    my $nav_now_left = $nav_now - $ps1_nom*$ps1_qty;

    if ($ps2_ticker =~ /\w/) {
      if ($ps2_qty*$ps2_nom > $nav_now_left) {
        $ps2_nav_ps = $nav_now_left/$ps2_qty;
      } else {
        $ps2_nav_ps = $ps2_nom;
        $cs_nav_ps = ($nav_now_left-$ps2_qty*$ps2_nom)/$cs_qty;
      }
    } else {
      $cs_nav_ps = $nav_now_left/$cs_qty;
    }
  }

  my $cs_nav_now  = $cs_nav_ps*$cs_qty;
  my $ps1_nav_now = $ps1_nav_ps*$ps1_qty;
  my $ps2_nav_now = $ps2_nav_ps*$ps2_qty if ($ps2_ticker =~ /\w/);

  my $cs_valu = -999.999;
  if ($cs_nav_ps > 0) {
    $cs_valu = 100.0*($cs_price_now/$cs_nav_ps);
  }

  my $ps1_valu = -999.999;
  if ($ps1_nav_ps > 0) {
    $ps1_valu = 100.0*($ps1_price_now/$ps1_nav_ps);
  }

  my $ps2_valu = -999.999;
  if($ps2_ticker =~ /\w/ && $ps2_nav_ps > 0) {
    $ps2_valu = 100.0*($ps2_price_now/$ps2_nav_ps);
  }

  my $cs_leverage = $market_cap_now/$cs_market_cap;

  my $cs_div_tot  = $cs_div*$cs_qty;
  my $ps1_div_tot = $ps1_div*$ps1_qty;
  my $ps2_div_tot = $ps2_div*$ps2_qty if ($ps2_ticker =~ /\w/);

  my $cs_div_pct  = 100.0*$cs_div_tot/$total_div_tot;
  my $ps1_div_pct = 100.0*$ps1_div_tot/$total_div_tot;
  my $ps2_div_pct = 100.0*$ps2_div_tot/$total_div_tot if ($ps2_ticker =~ /\w/);

  my $nav_unit_ps = $cs_nav_ps + $ps1_nav_ps;
  $nav_unit_ps   += $ps2_nav_ps if ($ps2_ticker =~ /\w/);
  my $unit_valu   = 100.0*($unit_price_now/$nav_unit_ps);

  ## Capital Shares Montly Retraction
  my $cs_ret_cost = $ps1_price_now;
  $cs_ret_cost += $ps2_price_now if ($ps2_ticker =~ /\w/);
  my $cs_ret = ($mon_pct/100.0)*$nav_unit_ps - $cs_ret_cost;
  my $cs_gain_pct = 100.0*($cs_ret/$cs_price_now-1);

  ## PS1 Shares Monthly Retraction
  my $ps1_ret_cost = $cs_price_now;
  $ps1_ret_cost += $ps2_price_now if ($ps2_ticker =~ /\w/);
  my $ps1_ret = ($mon_pct/100.0)*$nav_unit_ps - $ps1_ret_cost;
  $ps1_ret = $ps1_nom if ($ps1_ret > $ps1_nom);
  my $ps1_gain_pct = 100.0*($ps1_ret/$ps1_price_now-1);

  ## PS2 Shares Monthly Retraction
  my $ps2_ret_cost;
  my $ps2_ret;
  my $ps2_gain_pct;

  if ($ps2_ticker =~ /\w/) {
    $ps2_ret_cost = $cs_price_now + $ps1_price_now;
    $ps2_ret = ($mon_pct/100.0)*$nav_unit_ps - $ps2_ret_cost;
    $ps2_ret = $ps2_nom if ($ps2_ret > $ps2_nom);
    $ps2_gain_pct = 100.0*($ps2_ret/$ps2_price_now-1);
  }

  ## Annual Retraction Gain
  my $annual_ret = ($annual_pct/100.0)*$nav_unit_ps;
  my $annual_gain_pct = 100.0*($annual_ret/$unit_price_now-1);

  my ($ret_date_mon,$ret_dead_date_mon) = tt_retract_date($year_now,$mon_now,$days);
  my ($ret_date_annual,$ret_dead_date_annual) = tt_retract_date($year_now,$annual_mon,$days);
  if ($mon_now > $annual_mon) {
    ($ret_date_annual,$ret_dead_date_annual) = tt_retract_date($year_now+1,$annual_mon,$days);
  }

  print "CASH THEN:           " . fmt_money2($cash,0) . "\n";
  print "NAV THEN:            " . fmt_money2($nav,0) . "\n";
  print "NAV NOW:             " . fmt_money2($nav_now,0) . "\n";
  print "NAV CHANGE:          " . fmt_money2($nav_change,0) . "\n";
  print "CS  MARKET CAP:      " . fmt_money2($cs_market_cap,0) . "\n";
  print "PS1 MARKET CAP:      " . fmt_money2($ps1_market_cap,0) . "\n";
  print "PS2 MARKET CAP:      " . fmt_money2($ps2_market_cap,0) . "\n" if ($ps2_ticker =~ /\w/);
  print "TOTAL MARKET CAP:    " . fmt_money2($market_cap_now,0) . "\n";
  print "CS  SHARES:          " . fmt_money2($cs_qty,0) . "\n";
  print "PS1 SHARES:          " . fmt_money2($ps1_qty,0) . "\n";
  print "PS2 SHARES:          " . fmt_money2($ps2_qty,0) . "\n" if ($ps2_ticker =~ /\w/);
  print "CS  NOMINAL:         " . fmt_money2($cs_nom,3) . "\n";
  print "PS1 NOMINAL:         " . fmt_money2($ps1_nom,3) . "\n";
  print "PS2 NOMINAL:         " . fmt_money2($ps2_nom,3) . "\n" if ($ps2_ticker =~ /\w/);
  print "CS LEVERAGE          " . fmt_money2($cs_leverage,4) . "\n";
  print "CS  NAV NOW:         " . fmt_money2($cs_nav_ps*$cs_qty,0) . "\n";
  print "PS1 NAV NOW:         " . fmt_money2($ps1_nav_ps*$ps1_qty,0) . "\n";
  print "PS2 NAV NOW:         " . fmt_money2($ps2_nav_ps*$ps2_qty,0) . "\n" if ($ps2_ticker =~ /\w/);
  print "NOW NAV CHANGE PCT:  " . fmt_money2($nav_change_pct,2) . "%\n";
  print "\n";
 
  print "CS  PRICE THEN:      " . fmt_money2($cs_price,3) . "\n";
  print "PS1 PRICE THEN:      " . fmt_money2($ps1_price,3) . "\n";
  print "PS2 PRICE THEN:      " . fmt_money2($ps2_price,3) . "\n" if ($ps2_ticker =~ /\w/);
  print "UNIT PRICE THEN:     " . fmt_money2($unit_price,2) . "\n";
  print "CS  PRICE NOW:       " . fmt_money2($cs_price_now,3) . "\n";
  print "PS1 PRICE NOW:       " . fmt_money2($ps1_price_now,3) . "\n";
  print "PS2 PRICE NOW:       " . fmt_money2($ps2_price_now,3) . "\n" if ($ps2_ticker =~ /\w/);
  print "UNIT PRICE NOW:      " . fmt_money2($unit_price_now,2) . "\n";

  print "CS  PRICE CHANGE%:   " . fmt_money2($cs_price_change_pct,2) . "%\n";
  print "PS1 PRICE CHANGE%:   " . fmt_money2($ps1_price_change_pct,2) . "%\n";
  print "PS2 PRICE CHANGE%:   " . fmt_money2($ps2_price_change_pct,2) . "%\n" if ($ps2_ticker =~ /\w/);
  print "UNIT PRICE CHANGE%   " . fmt_money2($unit_price_change_pct,2) . "%\n";
  print "\n";

  print "CS  NAV PS:          " . fmt_money2($cs_nav_ps,3) . "\n";
  print "PS1 NAV PS:          " . fmt_money2($ps1_nav_ps,3) . "\n";
  print "PS2 NAV PS:          " . fmt_money2($ps2_nav_ps,3) . "\n" if ($ps2_ticker =~ /\w/);
  print "UNIT NAV PS:         " . fmt_money2($nav_unit_ps,2) . "\n";

  print "CS  VALUATION:       " . fmt_money2($cs_valu,2) . "%\n";
  print "PS1 VALUATION:       " . fmt_money2($ps1_valu,2) . "%\n";
  print "PS2 VALUATION:       " . fmt_money2($ps2_valu,2) . "%\n" if ($ps2_ticker =~ /\w/);
  print "UNIT VALUATION:      " . fmt_money2($unit_valu,2) . "%\n";
  print "\n";

  print "CS  DIVIDEND PS:     " . fmt_money2($cs_div,3) . "\n";
  print "PS1 DIVIDEND PS:     " . fmt_money2($ps1_div,3) . "\n";
  print "PS2 DIVIDEND PS:     " . fmt_money2($ps2_div,3) . "\n" if ($ps2_ticker =~ /\w/);

  print "CS  YIELD:           " . fmt_money2(100.0*$cs_div/$cs_price_now,3) . "%\n";
  print "PS1 YIELD:           " . fmt_money2(100.0*$ps1_div/$ps1_price_now,3) . "%\n";
  print "PS2 YIELD:           " . fmt_money2(100.0*$ps2_div/$ps2_price_now,3) . "%\n" if ($ps2_ticker =~ /\w/);

  print "NAV DIVIDEND:        " . fmt_money2($total_div_tot,0) . "\n";
  print "NAV YIELD:           " . fmt_money2($total_div_yield,2) . "%\n";
  print "CS  PAYOUT:          " . fmt_money2($cs_div_tot,0) . "\n";
  print "PS1 PAYOUT:          " . fmt_money2($ps1_div_tot,0) . "\n";
  print "PS2 PAYOUT:          " . fmt_money2($ps2_div_tot,0) . "\n" if ($ps2_ticker =~ /\w/);

  print "CS  PAYOUT RATIO:    " . fmt_money2($cs_div_pct,2) . "%\n";
  print "PS1 PAYOUT RATIO:    " . fmt_money2($ps1_div_pct,2) . "%\n";
  print "PS2 PAYOUT RATIO:    " . fmt_money2($ps2_div_pct,2) . "%\n" if ($ps2_ticker =~ /\w/);
  print "\n";

  print "CS  MON RET PS:      " . fmt_money2($cs_ret,2) . "\n";
  print "PS1 MON RET PS:      " . fmt_money2($ps1_ret,2) . "\n";
  print "PS2 MON RET PS:      " . fmt_money2($ps2_ret,2) . "\n" if ($ps2_ticker =~ /\w/);
  print "ANNUAL RET PS:       " . fmt_money2($annual_ret,2) . "\n";

  print "CS  MON RET GAIN:    " . fmt_money2($cs_gain_pct,2) . "%\n";
  print "PS1 MON RET GAIN:    " . fmt_money2($ps1_gain_pct,2) . "%\n";
  print "PS2 MON RET GAIN:    " . fmt_money2($ps2_gain_pct,2) . "%\n" if ($ps2_ticker =~ /\w/);
  print "ANNUAL RET GAIN:     " . fmt_money2($annual_gain_pct,2) . "%\n";

  print "MON RET DATE:        $ret_date_mon\n";
  print "MON RET DEADLINE:    $ret_dead_date_mon\n";

  print "ANNUAL RET DATE:     $ret_date_annual\n";
  print "ANNUAL RET DEADLINE: $ret_dead_date_annual\n";

  print "\n";
}
