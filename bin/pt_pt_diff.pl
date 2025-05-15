#!/usr/bin/env perl
use warnings;
use strict;
use Time::Local;

my %OPT;
use Getopt::Long;
GetOptions(\%OPT,"account=s");

use File::Basename;
use FindBin;
use lib "$FindBin::Bin/../lib";
use Tax::Txt;

my $USAGE = "$0 <pt text old> <pt text new>\n";
die $USAGE unless (@ARGV == 2);
my ($pt_file_old,$pt_file_new) = @ARGV;

open(IN,$pt_file_new) || die "Error: Can't read file '$pt_file_new': $!\n";
my %cols_new;
my %db_new;

while (<IN>) {

  if (/^\s*HEADER/) {
    %cols_new = tt_parse_header($_);

  } elsif (/^\s*HOLD/i) {

    die "Error: Didn't find header before HOLD lines in file '$pt_file_new'!\n" if (scalar keys %cols_new == 0);

    my @bits = split;
    
    my $account      = $bits[$cols_new{ACCOUNT}];
    my $symbol       = $bits[$cols_new{SYMBOL}];
    my $symbol_yahoo = $bits[$cols_new{SYMBOL_YAHOO}];
    my $curr         = $bits[$cols_new{CURRENCY}];
    my $status       = $bits[$cols_new{STATUS}];
    my $risk         = $bits[$cols_new{RISK}];
    my $sector       = $bits[$cols_new{SECTOR}];
    my $type         = $bits[$cols_new{TYPE}];
    my $qty          = $bits[$cols_new{QUANTITY}];
    my $cost         = $bits[$cols_new{COST}];
    my $price        = $bits[$cols_new{PRICE}];
    my $change       = $bits[$cols_new{CHANGE}];
    my $gain_pct     = $bits[$cols_new{GAIN_PCT}];
    my $div          = $bits[$cols_new{DIV}];
    my $yield        = $bits[$cols_new{YIELD}];
    my $div_tot      = $bits[$cols_new{DIV_TOT}];
    my $div_tot_cad  = $bits[$cols_new{DIV_TOT_CAD}];
    my $book         = $bits[$cols_new{BOOK}];
    my $value        = $bits[$cols_new{VALUE}];
    my $gain         = $bits[$cols_new{GAIN}];
    my $book_cad     = $bits[$cols_new{BOOK_CAD}];
    my $value_cad    = $bits[$cols_new{VALUE_CAD}];
    my $gain_cad     = $bits[$cols_new{GAIN_CAD}];

    $db_new{$account}{$symbol}{quantity} = $qty;
    $db_new{$account}{$symbol}{cost}     = $cost;
    $db_new{$account}{$symbol}{line}     = $_;
  }
}

open(IN,$pt_file_old) || die "Error: Can't read file '$pt_file_old': $!\n";
open(OUT,"| tabulate.pl -r | sort -b -k 2,2 -k 5,5 -k 3,3") || die "Error: Can't pipe to tabulate.pl: $!\n";

my %cols_old;

while (<IN>) {

  my $flag = 1;

  if (/^\s*HEADER/) {
    %cols_old = tt_parse_header($_);

  } elsif (/^\s*HOLD/i) {

    die "Error: Didn't find header before HOLD lines!\n" if (scalar keys %cols_old == 0);

    my @bits = split;
    
    my $account      = $bits[$cols_old{ACCOUNT}];
    my $symbol       = $bits[$cols_old{SYMBOL}];
    my $symbol_yahoo = $bits[$cols_old{SYMBOL_YAHOO}];
    my $curr         = $bits[$cols_old{CURRENCY}];
    my $status       = $bits[$cols_old{STATUS}];
    my $risk         = $bits[$cols_old{RISK}];
    my $sector       = $bits[$cols_old{SECTOR}];
    my $type         = $bits[$cols_old{TYPE}];
    my $qty          = $bits[$cols_old{QUANTITY}];
    my $cost         = $bits[$cols_old{COST}];
    my $price        = $bits[$cols_old{PRICE}];
    my $change       = $bits[$cols_old{CHANGE}];
    my $gain_pct     = $bits[$cols_old{GAIN_PCT}];
    my $div          = $bits[$cols_old{DIV}];
    my $yield        = $bits[$cols_old{YIELD}];
    my $div_tot      = $bits[$cols_old{DIV_TOT}];
    my $div_tot_cad  = $bits[$cols_old{DIV_TOT_CAD}];
    my $book         = $bits[$cols_old{BOOK}];
    my $value        = $bits[$cols_old{VALUE}];
    my $gain         = $bits[$cols_old{GAIN}];
    my $book_cad     = $bits[$cols_old{BOOK_CAD}];
    my $value_cad    = $bits[$cols_old{VALUE_CAD}];
    my $gain_cad     = $bits[$cols_old{GAIN_CAD}];


    if (exists $db_new{$account}) {
      if (exists $db_new{$account}{$symbol}) {

        $db_new{$account}{$symbol}{found_in_old} = 1;

        my $qty_new  = $db_new{$account}{$symbol}{quantity};
        my $cost_new = $db_new{$account}{$symbol}{cost};

        my $delta_q = $qty - $qty_new;
        my $delta_c = $cost - $cost_new;

        if (abs($delta_q) > 1e-3) {
          warn "Warning: Updating symbol '$symbol' from account '$account' has quantity '$qty' in old pt '$pt_file_old' but quantity '$qty_new' in new pt '$pt_file_new'\n";
          $flag = 0;
        }
        if (abs($delta_c) > 1e-3) {
          warn "Warning: Updating symbol '$symbol' from account '$account' has cost '$cost' in old pt '$pt_file_old' but cost '$cost_new' in new pt '$pt_file_new'\n";
          $flag = 0;
        }

        unless ($flag) {
          print OUT "HOLD $account $symbol $symbol_yahoo $curr $status $risk $sector $type $qty_new $cost_new $price $change $gain_pct $div $yield $div_tot $div_tot_cad $book $value $gain $book_cad $value_cad $gain_cad\n"; 
        }


      } else {
        
        # Symbol exists in old pt but not new one - delete
        warn "Warning: Deleting symbol '$symbol' from account '$account' from old pt '$pt_file_old' not found in new pt '$pt_file_new'\n";
        $flag = 0;
      }
    }
  }

  print OUT if ($flag);
}

foreach my $account (sort keys %db_new) {
  foreach my $symbol (sort keys %{$db_new{$account}}) {

    unless ($db_new{$account}{$symbol}{found_in_old}) {
      warn "Warning: Adding symbol '$symbol' from account '$account' not found in old pt '$pt_file_old' but exists in new pt file '$pt_file_new'\n";
      print OUT "$db_new{$account}{$symbol}{line}";
    }
  }
}
