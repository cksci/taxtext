#!/usr/bin/env perl
use warnings;
use strict;
use Time::Local;
use File::Basename;
my $dir = dirname($0);

my %OPT;
use Getopt::Long;
GetOptions(\%OPT,"year=s");

use FindBin;
use lib "$FindBin::Bin/../lib";
use Tax::Txt;

my $USAGE = "$0 <portfolio text> ...\n";
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

my %db;
my %dbs;
my %accounts;

my $zero = fmt_money2(0.0);

foreach my $fh (@fhs) {
  my %cols;

  while (<$fh>) {
    chomp;
    s/^\s+//;
    s/\s+$//;

    if (/^\s*HEADER/) {
      %cols = tt_parse_header($_);
    }

    if (/^\s*CASH/i) {
      die "Error: Didn't find header before CASH lines!\n" if (scalar keys %cols == 0);

      my @bits = split;

      my $account   = $bits[$cols{ACCOUNT}];
      my $curr      = $bits[$cols{CURRENCY}];
      my $value     = $bits[$cols{VALUE}];
      my $value_cad = $bits[$cols{VALUE_CAD}];

      $db{$account}{cash_cad} = 0 unless (exists $db{$account}{cash_cad});
      $db{$account}{cash_usd} = 0 unless (exists $db{$account}{cash_usd});  

      if ($curr eq 'CAD') {
        $db{$account}{cash_cad} += $value_cad;
      } elsif ($curr eq 'USD') {
        $db{$account}{cash_usd} += $value_cad;
      } else {
        warn "# Warning: Don't know how to handle currency '$curr' on line '$_'\n";
      }

      $db{$account}{equity_book}    = 0 unless (exists $db{$account}{equity_book});
      $db{$account}{equity_value}   = 0 unless (exists $db{$account}{equity_value});
      $db{$account}{equity_gain}    = 0 unless (exists $db{$account}{equity_gain});
      $db{$account}{equity_div_tot} = 0 unless (exists $db{$account}{equity_div_tot});

      $db{$account}{ccd_cad_book}  = 0 unless (exists $db{$account}{ccd_cad_book});
      $db{$account}{ccd_cad_value} = 0 unless (exists $db{$account}{ccd_cad_value});
      $db{$account}{ccd_cad_gain}  = 0 unless (exists $db{$account}{ccd_cad_gain});

      $db{$account}{ccd_usd_book}  = 0 unless (exists $db{$account}{ccd_usd_book});
      $db{$account}{ccd_usd_value} = 0 unless (exists $db{$account}{ccd_usd_value});
      $db{$account}{ccd_usd_gain}  = 0 unless (exists $db{$account}{ccd_usd_gain});

    } elsif (/^\s*HOLD/i) {

      die "Error: Didn't find header before HOLD lines!\n" if (scalar keys %cols == 0);

      my @bits = split;

      my $account      = $bits[$cols{ACCOUNT}];
      my $symbol       = $bits[$cols{SYMBOL}];
      my $symbol_yahoo = $bits[$cols{SYMBOL_YAHOO}];
      my $status       = $bits[$cols{STATUS}];
      my $risk         = $bits[$cols{RISK}];
      my $sector       = $bits[$cols{SECTOR}];
      my $type         = $bits[$cols{TYPE}];
      my $curr         = $bits[$cols{CURRENCY}];
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

      $db{$account}{cash_cad} = 0 unless (exists $db{$account}{cash_cad});
      $db{$account}{cash_usd} = 0 unless (exists $db{$account}{cash_usd});  
      
      $db{$account}{equity_book}    = 0 unless (exists $db{$account}{equity_book});
      $db{$account}{equity_value}   = 0 unless (exists $db{$account}{equity_value});
      $db{$account}{equity_gain}    = 0 unless (exists $db{$account}{equity_gain});
      $db{$account}{equity_div_tot} = 0 unless (exists $db{$account}{equity_div_tot});

      $db{$account}{ccd_cad_book}  = 0 unless (exists $db{$account}{ccd_cad_book});
      $db{$account}{ccd_cad_value} = 0 unless (exists $db{$account}{ccd_cad_value});
      $db{$account}{ccd_cad_gain}  = 0 unless (exists $db{$account}{ccd_cad_gain});

      $db{$account}{ccd_usd_book}  = 0 unless (exists $db{$account}{ccd_usd_book});
      $db{$account}{ccd_usd_value} = 0 unless (exists $db{$account}{ccd_usd_value});
      $db{$account}{ccd_usd_gain}  = 0 unless (exists $db{$account}{ccd_usd_gain});

      $dbs{$sector}{$account} = 0 unless (exists $dbs{$sector}{$account});
      $dbs{$sector}{$account} += $value_cad;
      $accounts{$account} = 1;

      if ($symbol =~ /(\w+)(\d\d\d\d\d\d)(C|P)(\d\d\d\d\d\d\d\d)/) {
        my ($underlying,$yymmdd,$callput,$strike) = ($1,$2,$3,$4);
        if ($curr eq 'CAD') {
          $db{$account}{ccd_cad_book}  += $book_cad;
          $db{$account}{ccd_cad_value} += $value_cad;
          $db{$account}{ccd_cad_gain}  += $gain_cad;
        } else {
          $db{$account}{ccd_usd_book}  += $book_cad;
          $db{$account}{ccd_usd_value} += $value_cad;
          $db{$account}{ccd_usd_gain}  += $gain_cad;
        }
      } else {
        $db{$account}{equity_book}    += $book_cad;
        $db{$account}{equity_value}   += $value_cad;
        $db{$account}{equity_gain}    += $gain_cad;
        $db{$account}{equity_div_tot} += $div_tot_cad;
      }
    }
  }
}

my $total_cash_cad      = 0;
my $total_cash_usd      = 0;

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

print "# All values in CAD\n";

open(OUT,"|$dir/tabulate.pl -r") || die "Error: Can't pipe to '$dir/tabulate.pl': $!\n";

print OUT "| ACCOUNT | \$CAD | \$USD | CCD_CAD | CCD_USD | BOOK | VALUE | TOT_VALUE | GAIN | GAIN% | CCD_CAD% | CCD_USD% | DIV | YIELD% |\n";

foreach my $account (sort keys %db) {

  my $cash_cad      = $db{$account}{cash_cad};
  my $cash_usd      = $db{$account}{cash_usd};
  my $ccd_cad_book  = $db{$account}{ccd_cad_book};
  my $ccd_cad_value = $db{$account}{ccd_cad_value};
  my $ccd_cad_gain  = $db{$account}{ccd_cad_gain};
  my $ccd_usd_book  = $db{$account}{ccd_usd_book};
  my $ccd_usd_value = $db{$account}{ccd_usd_value};
  my $ccd_usd_gain  = $db{$account}{ccd_usd_gain};
  my $book          = $db{$account}{equity_book};
  my $value         = $db{$account}{equity_value};
  my $gain          = $db{$account}{equity_gain};
  my $div_tot       = $db{$account}{equity_div_tot};

  my $value_all = $value + $cash_cad + $cash_usd + $ccd_cad_value + $ccd_usd_value;

  $total_cash_cad      += $cash_cad;
  $total_cash_usd      += $cash_usd;
  $total_book          += $book;
  $total_value         += $value;
  $total_gain          += $gain;
  $total_div_tot       += $div_tot;
  $total_ccd_cad_book  += $ccd_cad_book;
  $total_ccd_cad_value += $ccd_cad_value;
  $total_ccd_cad_gain  += $ccd_cad_gain;
  $total_ccd_usd_book  += $ccd_usd_book;
  $total_ccd_usd_value += $ccd_usd_value;
  $total_ccd_usd_gain  += $ccd_usd_gain;

  my $ccd_cad_gain_pct = $zero;
  if (abs($ccd_cad_book) > 1e-3) {
    $ccd_cad_gain_pct = 100.0*$ccd_cad_gain/$ccd_cad_book;
  }

  my $ccd_usd_gain_pct = $zero;
  if (abs($ccd_usd_book) > 1e-3) {
    $ccd_usd_gain_pct = 100.0*$ccd_usd_gain/$ccd_usd_book;
  }

  my $gain_pct  = $zero;
  my $yield_pct = $zero;

  if (abs($book) > 1e-3) {
    $gain_pct  = 100.0*$gain/$book;
    $yield_pct = 100.0*$div_tot/$value_all;
  }

  $cash_cad         = fmt_money2($cash_cad,0);
  $cash_usd         = fmt_money2($cash_usd,0);
  $ccd_cad_value    = fmt_money2($ccd_cad_value,0);
  $ccd_usd_value    = fmt_money2($ccd_usd_value,0);
  $book             = fmt_money2($book,0);
  $value            = fmt_money2($value,0);
  $gain             = fmt_money2($gain,0);
  $value_all        = fmt_money2($value_all,0);
  $gain_pct         = fmt_money2($gain_pct);
  $ccd_cad_gain_pct = fmt_money2($ccd_cad_gain_pct);
  $ccd_usd_gain_pct = fmt_money2($ccd_usd_gain_pct);
  $div_tot          = fmt_money2($div_tot,0);
  $yield_pct        = fmt_money2($yield_pct);
  $gain_pct         = fmt_money2($gain_pct);

  print OUT "| $account | $cash_cad | $cash_usd | $ccd_cad_value | $ccd_usd_value | $book | $value | $value_all | $gain | $gain_pct | $ccd_cad_gain_pct | $ccd_usd_gain_pct | $div_tot | $yield_pct |\n";
}

my $total_ccd_cad_gain_pct = $zero;
if (abs($total_ccd_cad_book) > 1e-3) {
  $total_ccd_cad_gain_pct = 100.0*$total_ccd_cad_gain/$total_ccd_cad_book;
}

my $total_ccd_usd_gain_pct = $zero;
if (abs($total_ccd_usd_book) > 1e-3) {
  $total_ccd_usd_gain_pct = 100.0*$total_ccd_usd_gain/$total_ccd_usd_book;
}

my $total_gain_pct    = 100.0*$total_gain/$total_book;
my $total_yield_pct   = 100.0*$total_div_tot/$total_value;

$total_book    = $total_book;
$total_value   = $total_value;
$total_gain    = $total_gain;
$total_div_tot = $total_div_tot;
my $total_value_with_cash = $total_value + $total_cash_usd + $total_cash_cad;

$total_ccd_cad_book  = $total_ccd_cad_book;
$total_ccd_cad_value = $total_ccd_cad_value;
$total_ccd_cad_gain  = $total_ccd_cad_gain;

$total_ccd_usd_book  = $total_ccd_usd_book;
$total_ccd_usd_value = $total_ccd_usd_value;
$total_ccd_usd_gain  = $total_ccd_usd_gain;

my $total_cash_cad_pct      = fmt_money2(100.0*$total_cash_cad/$total_value_with_cash);
my $total_cash_usd_pct      = fmt_money2(100.0*$total_cash_usd/$total_value_with_cash);
my $total_ccd_cad_value_pct = fmt_money2(100.0*$total_ccd_cad_value/$total_value_with_cash);
my $total_ccd_usd_value_pct = fmt_money2(100.0*$total_ccd_usd_value/$total_value_with_cash);
my $total_value_pct         = fmt_money2(100.0*$total_value/$total_value_with_cash);

$total_cash_cad         = fmt_money2($total_cash_cad,0);
$total_cash_usd         = fmt_money2($total_cash_usd,0);
$total_ccd_cad_value    = fmt_money2($total_ccd_cad_value,0);
$total_ccd_usd_value    = fmt_money2($total_ccd_usd_value,0);
$total_book             = fmt_money2($total_book,0);
$total_value            = fmt_money2($total_value,0);
$total_value_with_cash  = fmt_money2($total_value_with_cash,0);
$total_gain             = fmt_money2($total_gain,0);
$total_gain_pct         = fmt_money2($total_gain_pct);
$total_ccd_cad_gain_pct = fmt_money2($total_ccd_cad_gain_pct);
$total_ccd_usd_gain_pct = fmt_money2($total_ccd_usd_gain_pct);
$total_div_tot          = fmt_money2($total_div_tot,0);
$total_yield_pct        = fmt_money2($total_yield_pct);

print OUT "| TOTAL | $total_cash_cad | $total_cash_usd | $total_ccd_cad_value | $total_ccd_usd_value | $total_book | $total_value | $total_value_with_cash | $total_gain | $total_gain_pct | $total_ccd_cad_gain_pct | $total_ccd_usd_gain_pct | $total_div_tot | $total_yield_pct |\n";
print OUT "| TOTAL% | $total_cash_cad_pct | $total_cash_usd_pct | $total_ccd_cad_value_pct | $total_ccd_usd_value_pct | - | $total_value_pct | 100.00 | - | - | - | - | - | - |\n";
print OUT "\n";

open(OUT,"| tabulate.pl -r") || die "Error: Can't pipe to tabulate.pl: $!\n";
my $str = "| SECTOR";
foreach my $account (sort keys %accounts) {
  $str .= " | $account";
}
print OUT "$str | TOTAL |\n";

foreach my $sector (sort keys %dbs) {
  my $total = 0;
  my $str = "| $sector";
  foreach my $account (sort keys %accounts) {
    if (exists $dbs{$sector}{$account}) {
      $str .= " | " . fmt_money2($dbs{$sector}{$account});
      $total += $dbs{$sector}{$account}; 
    } else {
      $str .= " | $zero";
    }
  }
  $total = fmt_money2($total);
  print OUT "$str | $total |\n";
}
print OUT "\n";
