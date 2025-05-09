#!/usr/bin/env perl
use warnings;
use strict;
use Time::Local;

my %OPT;
use Getopt::Long;
GetOptions(\%OPT,"year=s");

use File::Basename;
use FindBin;
use lib "$FindBin::Bin/../lib";
use Tax::Txt;

my $USAGE = "$0 <portfoliotext>\n";
die $USAGE unless (@ARGV == 1);

my $file = $ARGV[0];
open(IN,$file) || die "Error: Can't read file '$file': $!\n";

my %db;
my %dbs;
my %accounts;

my $zero = fmt_money2(0.0);

while (<IN>) {

  if (/^\s*CASH/i) {
    my @bits = split;

    my $account = $bits[1];
    my $sector  = $bits[4];
    my $curr    = $bits[6];
    my $qty     = $bits[7];
    my $value   = $bits[17];

    $db{$account}{cash_cad} = 0 unless (exists $db{$account}{cash_cad});
    $db{$account}{cash_usd} = 0 unless (exists $db{$account}{cash_usd});  

    if ($curr eq 'CAD') {
      $db{$account}{cash_cad} += $qty;
    } elsif ($curr eq 'USD') {
      $db{$account}{cash_usd} += $qty;
    } else {
    }

  } elsif (/^\s*HOLD/i) {
    my @bits = split;

    my $account     = $bits[1];
    my $status      = $bits[2];
    my $risk        = $bits[3];
    my $sector      = $bits[4];
    my $symbol      = $bits[5];
    my $curr        = $bits[6];
    my $qty         = $bits[7];
    my $cost        = $bits[8];
    my $price       = $bits[9];
    my $change_pct  = $bits[10];
    my $gain_pct    = $bits[11];
    my $div         = $bits[12];
    my $yield       = $bits[13];
    my $div_tot     = $bits[14];
    my $div_tot_cad = $bits[15];
    my $book        = $bits[16];
    my $value       = $bits[17];
    my $gain        = $bits[18];
    my $book_cad    = $bits[19];
    my $value_cad   = $bits[20];
    my $gain_cad    = $bits[21];
    
    foreach my $catt (qw(equity ccd_cad ccd_usd)) {
      foreach my $key (qw(book_cad value_cad gain_cad)) {
        my $str = "${catt}_$key";
        $db{$account}{$str} = 0 unless (exists $db{$account}{$str});
      }
    }
    $dbs{$sector}{$account} = 0 unless (exists $dbs{$sector}{$account});
    $dbs{$sector}{$account} += $value_cad;
    $accounts{$account} = 1;

    if ($symbol =~ /(\w+)(\d\d\d\d\d\d)(C|P)(\d\d\d\d\d\d\d\d)/) {
      my ($underlying,$yymmdd,$callput,$strike) = ($1,$2,$3,$4);
      if ($curr eq 'CAD') {
        $db{$account}{ccd_cad_book_cad}  += $book_cad;
        $db{$account}{ccd_cad_value_cad} += $value_cad;
        $db{$account}{ccd_cad_gain_cad}  += $gain_cad;
      } else {
        $db{$account}{ccd_usd_book_cad}  += $book_cad;
        $db{$account}{ccd_usd_value_cad} += $value_cad;
        $db{$account}{ccd_usd_gain_cad}  += $gain_cad;
      }
    } else {
      $db{$account}{equity_book_cad}    += $book_cad;
      $db{$account}{equity_value_cad}   += $value_cad;
      $db{$account}{equity_gain_cad}    += $gain_cad;
      $db{$account}{equity_div_tot_cad} += $div_tot_cad;
    }
  }
}

my $total_book          = 0;
my $total_value         = 0;
my $total_gain          = 0;
my $total_div_tot       = 0;

my $total_ccd_cad_book  = 0;
my $total_ccd_cad_value = 0;
my $total_ccd_cad_gain  = 0;

my $total_ccd_usd_book  = 0;
my $total_ccd_usd_value = 0;
my $total_ccd_usd_gain  = 0;

open(OUT,"| tabulate.pl -r") || die "Error: Can't pipe to tabulate.pl: $!\n";
print OUT "ACCOUNT CASH_CAD CASH_USD CCD_CAD CCD_USD BOOK VALUE GAIN GAIN% CCD_CAD_GAIN% CCD_USD_GAIN% DIV_CAD YIELD%\n";

foreach my $account (sort keys %db) {
  my $cash_cad = $db{$account}{cash_cad};
  my $cash_usd = $db{$account}{cash_usd};  

  my $ccd_cad_book  = $db{$account}{ccd_cad_book_cad};
  my $ccd_cad_value = $db{$account}{ccd_cad_value_cad};
  my $ccd_cad_gain  = $db{$account}{ccd_cad_gain_cad};

  my $ccd_cad_gain_pct = $zero;
  if ($ccd_cad_book > 0) {
    $ccd_cad_gain_pct = 100.0*$ccd_cad_gain/$ccd_cad_book;
  }

  my $ccd_usd_book  = $db{$account}{ccd_usd_book_cad};
  my $ccd_usd_value = $db{$account}{ccd_usd_value_cad};
  my $ccd_usd_gain  = $db{$account}{ccd_usd_gain_cad};

  my $ccd_usd_gain_pct = $zero;
  if ($ccd_usd_book > 0) {
    $ccd_usd_gain_pct = 100.0*$ccd_usd_gain/$ccd_usd_book;
  }

  my $book    = $db{$account}{equity_book_cad};
  my $value   = $db{$account}{equity_value_cad};
  my $gain    = $db{$account}{equity_gain_cad};
  my $div_tot = $db{$account}{equity_div_tot_cad};

  my $gain_pct    = 100.0*$gain/$book;
  my $yield_pct   = 100.0*$div_tot/$value;

  $total_book    += $book;
  $total_value   += $value;
  $total_gain    += $gain;
  $total_div_tot += $div_tot;

  $total_ccd_cad_book  += $ccd_cad_book;
  $total_ccd_cad_value += $ccd_cad_value;
  $total_ccd_cad_gain  += $ccd_cad_gain;

  $total_ccd_usd_book  += $ccd_usd_book;
  $total_ccd_usd_value += $ccd_usd_value;
  $total_ccd_usd_gain  += $ccd_usd_gain;

  $cash_cad         = fmt_money2($cash_cad);
  $cash_usd         = fmt_money2($cash_usd);
  $ccd_cad_value    = fmt_money2($ccd_cad_value);
  $ccd_usd_value    = fmt_money2($ccd_usd_value);
  $book             = fmt_money2($book);
  $value            = fmt_money2($value);
  $gain             = fmt_money2($gain);
  $gain_pct         = fmt_money2($gain_pct);
  $ccd_cad_gain_pct = fmt_money2($ccd_cad_gain_pct);
  $ccd_usd_gain_pct = fmt_money2($ccd_usd_gain_pct);
  $div_tot          = fmt_money2($div_tot);
  $yield_pct        = fmt_money2($yield_pct);
  $gain_pct         = fmt_money2($gain_pct);
  $ccd_cad_gain_pct = fmt_money2($ccd_cad_gain_pct);
  $ccd_usd_gain_pct = fmt_money2($ccd_usd_gain_pct);
  $div_tot          = fmt_money2($div_tot);
  $yield_pct        = fmt_money2($yield_pct);

  print OUT "$account $cash_cad $cash_usd $ccd_cad_value $ccd_usd_value $book $value $gain $gain_pct $ccd_cad_gain_pct $ccd_usd_gain_pct $div_tot $yield_pct\n";
}

my $total_ccd_cad_gain_pct = $zero;
if ($total_ccd_cad_book > 0) {
  $total_ccd_cad_gain_pct = 100.0*$total_ccd_cad_gain/$total_ccd_cad_book;
}

my $total_ccd_usd_gain_pct = $zero;
if ($total_ccd_usd_book > 0) {
  $total_ccd_usd_gain_pct = 100.0*$total_ccd_usd_gain/$total_ccd_usd_book;
}

my $total_gain_pct    = 100.0*$total_gain/$total_book;
my $total_yield_pct   = 100.0*$total_div_tot/$total_value;

$total_book    = $total_book;
$total_value   = $total_value;
$total_gain    = $total_gain;
$total_div_tot = $total_div_tot;

$total_ccd_cad_book  = $total_ccd_cad_book;
$total_ccd_cad_value = $total_ccd_cad_value;
$total_ccd_cad_gain  = $total_ccd_cad_gain;

$total_ccd_usd_book  = $total_ccd_usd_book;
$total_ccd_usd_value = $total_ccd_usd_value;
$total_ccd_usd_gain  = $total_ccd_usd_gain;

$total_ccd_cad_value    = fmt_money2($total_ccd_cad_value);
$total_ccd_usd_value    = fmt_money2($total_ccd_usd_value);
$total_book             = fmt_money2($total_book);
$total_value            = fmt_money2($total_value);
$total_gain             = fmt_money2($total_gain);
$total_gain_pct         = fmt_money2($total_gain_pct);
$total_ccd_cad_gain_pct = fmt_money2($total_ccd_cad_gain_pct);
$total_ccd_usd_gain_pct = fmt_money2($total_ccd_usd_gain_pct);
$total_div_tot          = fmt_money2($total_div_tot);
$total_yield_pct        = fmt_money2($total_yield_pct);

print OUT "TOTAL $zero $zero $total_ccd_cad_value $total_ccd_usd_value $total_book $total_value $total_gain $total_gain_pct $total_ccd_cad_gain_pct $total_ccd_usd_gain_pct $total_div_tot $total_yield_pct\n";
print OUT "\n";

open(OUT,"| tabulate.pl -r") || die "Error: Can't pipe to tabulate.pl: $!\n";
my $str = "SECTOR";
foreach my $account (sort keys %accounts) {
  $str .= " $account";
}
print OUT "$str TOTAL\n";

foreach my $sector (sort keys %dbs) {
  my $total = 0;
  my $str = "$sector";
  foreach my $account (sort keys %accounts) {
    if (exists $dbs{$sector}{$account}) {
      $str .= " " . fmt_money2($dbs{$sector}{$account});
      $total += $dbs{$sector}{$account}; 
    } else {
      $str .= " $zero";
    }
  }
  $total = fmt_money2($total);
  print OUT "$str $total\n";
}