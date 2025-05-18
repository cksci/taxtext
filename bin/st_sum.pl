#!/usr/bin/env perl
use warnings;
use strict;
use Time::Local;

my %OPT;
use Getopt::Long;
GetOptions(\%OPT,"date=s");

use File::Basename;
use FindBin;
use lib "$FindBin::Bin/../lib";
use Tax::Txt;

my $USAGE = "$0 [-date %m/%d/%y] <splitcorp text> ...\n";
die $USAGE unless (@ARGV > 0);

my $date_to = tt_get_date();
if (exists $OPT{date}) {
  $date_to = $OPT{date};
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
  my $date_n = tt_get_latest_date(keys %nav);

  my $nav        = $nav{$date_n}{nav};
  my $cash_pct   = $nav{$date_n}{cash_pct};
  my $cs_ticker  = $nav{$date_n}{cs_ticker};
  my $ps1_ticker = $nav{$date_n}{ps1_ticker};
  my $ps2_ticker = $nav{$date_n}{ps2_ticker};
  my $cs_qty     = $nav{$date_n}{cs_qty};
  my $ps1_qty    = $nav{$date_n}{ps1_qty};
  my $ps2_qty    = $nav{$date_n}{ps2_qty};
  my $cs_price   = $nav{$date_n}{cs_price};
  my $ps1_price  = $nav{$date_n}{ps1_price};
  my $ps2_price  = $nav{$date_n}{ps2_price};
  my $cs_nom     = $nav{$date_n}{cs_nom};
  my $ps1_nom    = $nav{$date_n}{ps1_nom};
  my $ps2_nom    = $nav{$date_n}{ps2_nom};

  # Scale equity based on new cash weight
  my $cash_w_old   = $weight{$date_w}{CASH};
  my $equity_w_old = 100-$cash_w_old;

  my $cash_w_new   = $cash_pct;
  my $equity_w_new = 100-$cash_w_new;

  my $scaler   = sprintf("%.6f",$equity_w_new/$equity_w_old);
  my $cash_new = sprintf("%.0f",$nav*$cash_w_new/100.0);

  print "DATE OLD:            $date_w\n";
  print "CASH WEIGHT OLD:     $cash_w_old\n"; 
  print "EQUITY WEIGHT OLD:   $equity_w_old\n";
  print "DATE NAV:            $date_n\n";
  print "CASH WEIGHT NAV:     $cash_w_new\n"; 
  print "EQUITY WEIGHT NAV:   $equity_w_new\n";
  print "EQUITY SCALER:       $scaler\n";

  my ($usdcad_n,)  = yf_parse("USDCAD=X",$date_n);
  my ($usdcad_to,) = yf_parse("USDCAD=X",$date_to);

  my $nav_to = $nav*$cash_w_new/100.0;

  open(OUT, "|tabulate.pl -r") || die;
  print "\n";
  print OUT "TICKER SHARES CURRENCY PRICE_ORG PRICE_NEW CHANGE_PCT NAV_ORG NAV_NEW\n";

  foreach my $ticker (keys %{$weight{$date_w}}) {
    next if ($ticker eq "CASH");

    my $w = $weight{$date_w}{$ticker};
    my $w_new = $scaler*$w;

    my ($price,$curr)     = yf_parse($ticker,$date_n);
    my ($price_to,$curr2) = yf_parse($ticker,$date_to);
    my $change_pct        = sprintf("%.2f",100*($price_to/$price-1));

    my $nav_new = $nav*$w_new/100.0;

    my $shares_n = sprintf("%.0f",$nav_new/$price);
    my $value;
    my $value_to;

    if ($curr eq "USD") {
      $shares_n    = sprintf("%.0f",$nav_new/$price/$usdcad_n);
      my $value    = $shares_n*$price*$usdcad_n;
      my $value_to = $shares_n*$price_to*$usdcad_to;
    } else {
      my $value    = $shares_n*$price;
      my $value_to = $shares_n*$price_to;
    }

    print OUT "$ticker " . fmt_money2($shares_n,0) . " $curr " . fmt_money2($price,2) . " " . fmt_money2($price_to,2) . " $change_pct " . fmt_money2($value,0) . " " . fmt_money2($value_to,0) . "\n";

    my $nav_to += $value_to;
  }
  close(OUT);

  my $nav_change_pct = sprintf("%.2f",100*($nav_to/$nav-1));

  print "NAV OLD:             " . fmt_money2($nav,0) . "\n";
  print "NAV NEW:             " . fmt_money2($nav_to,0) . "\n";
  print "NAVE CHANGE PCT:     $nav_change_pct\n";

  my $cs_price_to  = yf_parse($cs_ticker,$date_to);
  my $ps1_price_to = yf_parse($ps1_ticker,$date_to);

  my $ps2_price_to = "-";
  if ($ps2_ticker =~ /\w/) {
    $ps2_price_to = yf_parse($ps2_ticker,$date_to);
  }

  my $cs_nav  = 0;
  my $ps1_nav = 0;
  my $ps2_nav = 0;


  if ($nav_to > $ps1_nom) {
    $ps1_nav = $ps1_nom;

    if ($ps2_ticker =~ /\w/) {
      if ($nav_to > $ps1_nom+$ps2_nom) {
        $ps2_nav = $ps2_nom;
        $cs_nav = $nav_to-$ps1_nom-$ps2_nom;
      } else {
        $ps2_nav = $nav_to-$ps1_nom;
      }
    } else {
      $cs_nav = $nav_to-$ps1_nom;
    }
  } else {
    $ps1_nav = $nav;
  }

  my $ps1_disc = $ps1_nav/$ps1_nom;
  my $cs_disc = $cs_nav/$cs_nom;

  my $ps2_disc = "-";
  if($ps2_ticker =~ /\w/) {
    $ps2_disc = $ps2_nav/$ps2_nom;
  }

  print "CS PRICE:            $cs_price\n";
  print "PS1 PRICE:           $ps1_price\n";

  if ($ps2_ticker =~ /\w/) {
    print "PS2 PRICE:           $ps2_price\n";
  } else {
    print "PS2 PRICE:           -\n";
  }

  print "CS NAV:              $cs_nav\n";
  print "PS1 NAV:             $ps1_nav\n";
  print "PS2 NAV:             $ps2_nav\n";
  print "CS DISCOUNT:         $cs_disc\n";
  print "PS1 DISCOUNT:        $ps1_disc\n";
  print "PS2 DISCOUNT:        $ps2_disc\n";
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
