#!/usr/bin/env perl
use warnings;
use strict;
use Time::Local;
use File::Basename;
my $dir = dirname($0);

my %OPT;
use Getopt::Long;
GetOptions(\%OPT,"account=s");

use File::Basename;
use FindBin;
use lib "$FindBin::Bin/../lib";
use Tax::Txt;

my $USAGE = "$0 <portfoliott> <taxtext>\n";
die $USAGE unless (@ARGV == 2);
my ($pt_file,$tt_file) = @ARGV;

my %tt;       # Stores data of gains tt
my %tt_found; # Stores symbols that exist in gains tt that are found in portfolio tt

open(IN,$tt_file) || die "Error: Can't read file '$tt_file': $!\n";
while (<IN>) {
  if (/^\s*COST/) {
    my %bits = tt_parse_cost_line($_);
    $tt{$bits{symbol}}{quantity} = $bits{quantity};
    $tt{$bits{symbol}}{cost} = $bits{cost};
    $tt_found{$bits{symbol}} = 0;
  }
}

my %cols;

open(IN,$pt_file) || die "Error: Can't read file '$pt_file': $!\n";
open(OUT,"|$dir/tt_tab.pl -r") || die "Error: Can't pipe to '$dir/tt_tab.pl': $!\n";

while (<IN>) {

  my $flag = 1;

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

    if (exists $OPT{account} && $OPT{account} eq $account) {
      if (exists $tt{$symbol}) {

        $tt_found{$symbol} = 1;

        my $qty_new = $tt{$symbol}{quantity};
        my $cost_new = $tt{$symbol}{cost};

        my $delta_q = $qty - $qty_new;
        my $delta_c = $cost - $cost_new;

        if (abs($delta_q) > 1e-3) {
          warn "# Warning: Symbol '$symbol' has quantity $qty in portfolio tt but $qty_new in gains tt\n";
          $flag = 0;
        }
        if (abs($delta_c) > 1e-3) {
          warn "# Warning: Symbol '$symbol' has cost $cost in portfolio tt but $cost_new in gains tt\n";
          $flag = 0;
        }

        unless ($flag) {
          print OUT "HOLD $account $symbol $symbol_yahoo $curr $status $risk $sector $type $qty_new $cost_new $price $change $gain_pct $div $yield $div_tot $div_tot_cad $book $value $gain $book_cad $value_cad $gain_cad\n"; 
        }
        
      } else {
        warn "# Warning: Symbol '$symbol' is in portfolio tt but not gains tt\n";
      }
    }
  }

  print OUT if ($flag);
}

foreach my $symbol (sort keys %tt_found) {
  unless ($tt_found{$symbol}) {
    warn "# Warning: Symbol '$symbol' exists in gains tt but not in portfolio tt\n";
  }
}
