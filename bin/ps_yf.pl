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

my $USAGE = "$0 [-date %m/%d/%y] <preferredshare text> ...\n";
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
  open(OUT, "|$dir/tt_tab.pl -right -head") || die "Error: Can't pipe to '$dir/tt_tab.pl': $!\n";

  while (<IN>) {
    if (/^\s*#/ || /^\s*TICKER/ || /^\s*\*\d/) {
      print OUT;
      next;
    }

    chomp;
    s/^\s+//;
    s/\s+$//;
    s/\s+/ /g;
    s/,//g;

    if (/^(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)/) {
      my ($ticker,$curr,$callable,$type,$duration,$convertible,$date_reset,$reference,$spread,$price,$yield,$volume,$shares,$cap) = ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14);

      my $price_now;
      my $div;
      if ($curr eq "CAD") {
        ($price_now,$div) = yf_parse($ticker,$date_now);
      } else {
        ($price_now,$div) = yf_parse($ticker,$date_us_now);
      }
      my $yield_now = sprintf("%.2f",100.0*$div/$price_now);
      my $cap_now = "-";
      if ($shares =~ /\d/) {
        $cap_now = fmt_money2($shares*$price_now,0);
        $shares = fmt_money2($shares,0);
      }
      $div = fmt_money2($div,2);
      $price_now = fmt_money2($price_now,2);
      print OUT "$ticker $curr $callable $type $duration $convertible $date_reset $reference $spread $price_now $div $yield_now $volume $shares $cap_now\n";

    }
  }
}
