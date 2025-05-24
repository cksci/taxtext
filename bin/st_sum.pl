#!/usr/bin/env perl
use warnings;
use strict;
use Time::Local;
use File::Basename;
my $dir = dirname($0);

my %OPT;
use Getopt::Long;
GetOptions(\%OPT,"date=s");

use FindBin;
use lib "$FindBin::Bin/../lib";
use Tax::Txt;

my $USAGE = "$0 [-date %m/%d/%y] <splitcorp text> ...\n";
die $USAGE unless (@ARGV > 0);

my $date_now = tt_get_date();
if (exists $OPT{date}) {
  $date_now = $OPT{date};
}

my %nav;
my %weight;

foreach my $file (@ARGV) {
  open(IN,$file) || die "Error: Can't read file '$file': $!\n";
  while (<IN>) {

    chomp;
    s/#.*//g;
    s/^\s+//;
    s/\s+$//;
    s/\s+/ /g;
    s/,//g;

    if (/^NAV\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)/i) {
      my ($date,$nav,$cash_pct,$cs_ticker,$ps1_ticker,$ps2_ticker,$cs_qty,$ps1_qty,$ps2_qty,$cs_price,$ps1_price,$ps2_price,$cs_nom,$ps1_nom,$ps2_nom) = ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15);

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

    } elsif (/^WEIGHT\s+(\S+)\s+(\S+)\s+(\S+)/i) {
      my ($date,$ticker,$pct) = ($1,$2,$3);
      $weight{$date}{$ticker} = $pct;
    }
  }

  foreach my $date (sort keys %weight) {
    my $total = 0;
    foreach my $ticker (keys %{$weight{$date}}) {
      $total += $weight{$date}{$ticker};
    }

    if (abs($total - 100) > 1e-3) {
      warn "Warning: Total weight for date '$date' is $total not 100\n";
    }
  }

  my $date_w = tt_get_latest_date(keys %weight);
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

  # Scale equity based on new cash weight
  my $cash_w_old   = $weight{$date_w}{CASH};
  my $equity_w_old = 100-$cash_w_old;

  my $cash_w   = $cash_pct;
  my $equity_w = 100-$cash_w;

  my $scaler = sprintf("%.6f",$equity_w/$equity_w_old);
  my $cash   = sprintf("%.0f",$nav*$cash_w/100.0);

  print "DATE OLD:            $date_w\n";
  print "CASH WEIGHT OLD:     $cash_w_old\n"; 
  print "EQUITY WEIGHT OLD:   $equity_w_old\n";
  print "DATE:                $date\n";
  print "CASH WEIGHT:         $cash_w\n"; 
  print "EQUITY WEIGHT:       $equity_w\n";
  print "EQUITY SCALER:       $scaler\n";
  print "CS TICKER:           $cs_ticker\n";
  print "PS1 TICKER:          $ps1_ticker\n";
  print "PS2 TICKER:          $ps2_ticker\n";

  my ($usdcad,)     = yf_parse("USDCAD=X",$date);
  my ($usdcad_now,) = yf_parse("USDCAD=X",$date_now);

  my $nav_now = $cash;

  open(OUT, "|$dir/tt_tab.pl -right -box") || die "Error: Can't pipe to '$dir/tt_tab.pl': $!\n";
  print "\n";
  print OUT "TICKER SHARES CURRENCY PRICE_THEN PRICE_NOW NAV_THEN NAV_NOW CHANGE_PCT\n";

  foreach my $ticker (sort keys %{$weight{$date_w}}) {
    next if ($ticker eq "CASH");

    my $nav_ticker = $nav*$scaler*$weight{$date_w}{$ticker}/100.0;

    my ($price,$curr)      = yf_parse($ticker,$date);
    my ($price_now,$curr2) = yf_parse($ticker,$date_now);
    my $change_pct         = sprintf("%.2f",100*($price_now/$price-1));

    my $shares;
    my $value;
    my $value_now;

    if ($curr eq "USD") {
      $shares    = sprintf("%.0f",$nav_ticker/$price/$usdcad);
      $value     = $shares*$price*$usdcad;
      $value_now = $shares*$price_now*$usdcad_now;
    } else {
      $shares    = sprintf("%.0f",$nav_ticker/$price);
      $value     = $shares*$price;
      $value_now = $shares*$price_now;
    }

    print OUT "$ticker " . fmt_money2($shares,0) . " $curr " . fmt_money2($price,2) . " " . fmt_money2($price_now,2) . " " . fmt_money2($value,0) . " " . fmt_money2($value_now,0) . " $change_pct\n";

    $nav_now += $value_now;
  }
  close(OUT);
  print "\n";

  my $nav_change_pct = sprintf("%.2f",100*($nav_now/$nav-1));

  my ($cs_price_now,)  = yf_parse($cs_ticker,$date_now);
  my ($ps1_price_now,) = yf_parse($ps1_ticker,$date_now);

  my $unit_price_now = $cs_price_now + $ps1_price_now;
  my $value_now      = $cs_qty*$cs_price_now + $ps1_qty*$ps1_price_now;

  my $ps2_price_now = "-";
  if ($ps2_ticker =~ /\w/) {
    ($ps2_price_now,) = yf_parse($ps2_ticker,$date_now);
    $unit_price_now = $cs_price_now+$ps1_price_now+$ps2_price_now;
    $value_now      = $cs_qty*$cs_price_now + $ps1_qty*$ps1_price_now + $ps2_qty*$ps2_price_now;
  }

  my $cs_price_change_pct = fmt_money2(100.0*($cs_price_now/$cs_price-1),2);
  my $ps1_price_change_pct = fmt_money2(100.0*($ps1_price_now/$ps1_price-1),2);
  my $ps2_price_change_pct = fmt_money2(100.0*($ps2_price_now/$ps2_price-1),2) if ($ps2_ticker =~ /\w/);

  print "CASH:                " . fmt_money2($cash,0) . "\n";
  print "NAV:                 " . fmt_money2($nav,0) . "\n";
  print "NAV NOW:             " . fmt_money2($nav_now,0) . "\n";
  print "NAV CHANGE PCT:      $nav_change_pct\n";
  print "VALUE NOW:           " . fmt_money2($value_now,0) . "\n";

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

  my $nav_valu = 100.0*($value_now/$nav_now);
  my $cs_valu = "999.99";
  if ($cs_nav_ps > 0) {
    $cs_valu  = 100.0*($cs_price_now/$cs_nav_ps);
  }
  my $ps1_valu = 100.0*($ps1_price_now/$ps1_nav_ps);

  my $ps2_valu = "-";
  if($ps2_ticker =~ /\w/) {
    $ps2_valu = 100.0*($ps2_price_now/$ps2_nav_ps);
  }


  my $cs_leverage = "999.99";
  if ($cs_nav_now > 0) {
    $cs_leverage = $value_now/$cs_nav_now;
  }
  print "CS LEVERAGE          " . fmt_money2($cs_leverage,4) . "\n";

  print "CS NAV NOW:          " . fmt_money2($cs_nav_ps*$cs_qty,0) . "\n";
  print "PS1 NAV NOW:         " . fmt_money2($ps1_nav_ps*$ps1_qty,0) . "\n";
  print "PS2 NAV NOW:         " . fmt_money2($cs_nav_ps*$cs_qty,0) . "\n" if ($ps2_ticker =~ /\w/);

  print "CS NOMINAL:          " . fmt_money2($cs_nom,3) . "\n";
  print "PS1 NOMINAL:         " . fmt_money2($ps1_nom,3) . "\n";
  print "PS2 NOMINAL:         " . fmt_money2($ps2_nom,3) . "\n" if ($ps2_ticker =~ /\w/);

  print "CS PRICE THEN:       " . fmt_money2($cs_price,3) . "\n";
  print "PS1 PRICE THEN:      " . fmt_money2($ps1_price,3) . "\n";
  print "PS2 PRICE THEN:      " . fmt_money2($ps2_price,3) . "\n" if ($ps2_ticker =~ /\w/);

  print "CS PRICE NOW:        " . fmt_money2($cs_price_now,3) . "\n";
  print "PS1 PRICE NOW:       " . fmt_money2($ps1_price_now,3) . "\n";
  print "PS2 PRICE NOW:       " . fmt_money2($ps2_price_now,3) . "\n" if ($ps2_ticker =~ /\w/);

  print "CS PRICE CHANGE:     $cs_price_change_pct%\n";
  print "PS1 PRICE CHANGE:    $ps1_price_change_pct%\n";
  print "PS2 PRICE CHANGE:    $ps2_price_change_pct%\n" if ($ps2_ticker =~ /\w/);

  print "CS NAV PER SHARE:    " . fmt_money2($cs_nav_ps,3) . "\n";
  print "PS1 NAV PER SHARE:   " . fmt_money2($ps1_nav_ps,3) . "\n";
  print "PS2 NAV PER SHARE:   " . fmt_money2($ps2_nav_ps,3) . "\n" if ($ps2_ticker =~ /\w/);

  print "UNIT PRICE:          " . fmt_money2($unit_price_now,3) . "\n";
  print "CS VALUATION:        " . fmt_money2($cs_valu,2) . "\n";
  print "PS1 VALUATION:       " . fmt_money2($ps1_valu,2) . "\n";
  print "PS2 VALUATION:       " . fmt_money2($ps2_valu,2) . "\n" if ($ps2_ticker =~ /\w/);
  print "NAV VALUATION:       " . fmt_money2($nav_valu,2) . "\n";
}

sub yf_parse {
  my ($ticker,$date) = @_;
  #print "yf $ticker $date $date\n";
  my $str = `yf $ticker $date $date`;
  if ($str =~ /^\s*(\S+)\s+(\S+)\s+(\S+)\s+(\S+)/) {
    my ($t,$c,$d,$v) = ($1,$2,$3,$4);
    return ($v,$c);
  } else {
    die;
  }
}
