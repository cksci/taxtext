package Tax::Txt;

use strict;
use warnings;

use Exporter qw(import);
our @EXPORT = qw(fmt_money fmt_money2 map_ticker calc_fee convert_date get_date_year fmt_qty fmt_symbol);

sub fmt_money {
  my $value = shift;
  $value =~ s/,//g;
  $value =~ s/"//g;
  return sprintf("%.5f",$value);
}

sub fmt_money2 {
  my ($number) = @_;
  $number =~ s/,//g;
  $number = sprintf("%.2f",$number);
  my ($integer,$fraction) = split(/\./,$number);
  $integer =~ s/(?<=\d)(?=(\d{3})+$)/,/g;
  return defined $fraction ? "$integer.$fraction" : $integer;
}

# Maps ticker from what appears in the brokerage csv to Yahoo finance style ex. AEM.TO
sub map_ticker {
  my $ticker = shift;
  $ticker =~ s/\.USD$//;
  $ticker =~ s/\.CAD$/.TO/;
  $ticker =~ s/\.PR\.(\w)/-P$1/;
  return $ticker;
}

sub calc_fee {
  my ($value,$price,$quantity) = @_;

  my $fee = fmt_money(abs(abs($value)-$price*abs($quantity)));
  return $fee;
#  if ($fee =~ /^(6\.95|9\.95)$/) {
#    return $fee;
#  } else {
#    my $delta1 = abs(6.95-$fee);
#    my $delta2 = abs(9.95-$fee);
#    if ($delta1 < $delta2) {
#      return 6.95;
#    } else {
#      return 9.95;
#    }
#  }
}

sub convert_date {
  my $str = shift;
  $str =~ s/"//g;

  if ($str =~ /^\s*(\S+)\s+(\d+)\s*,\s+(\d+)/) {

    my ($month,$day,$year) = ($1,$2,$3);
    $month = month_num($month);
    return "$month/$day/$year";

  } elsif ($str =~ /^\s*(\d+)\-([a-z]+)\-(\d+)/i) {

    my ($day,$month,$year) = ($1,$2,$3);
    $year += 2000 if ($year < 2000);
    $month = month_num($month);
    return "$month/$day/$year";

  } elsif ($str =~ /^\s*(\d+)\-(\d+)\-(\d+)/i) {

    my ($year,$month,$day) = ($1,$2,$3);
    return "$month/$day/$year";

  } elsif ($str =~ /^\s*(\d+)\/(\d+)\/(\d+)/) {
    return "$1/$2/$3";

  } elsif ($str =~ /^\s*(\d+)(\w+)(\d+)/) {
    # BCE 15JAN27 34 C
    my ($day,$month,$year) = ($1,$2,$3);
    $year += 2000 if ($year < 2000);
    $month = month_num($month);
    return "$month/$day/$year";

  } else {
    die "Error: Can't parse date of '$str'\n";
  }
}

sub month_num {
  my $month = shift;
  if ($month =~ /jan/i) {
    $month = 1;
  } elsif ($month =~ /feb/i) {
    $month = 2;
  } elsif ($month =~ /mar/i) {
    $month = 3;
  } elsif ($month =~ /apr/i) {
    $month = 4;
  } elsif ($month =~ /may/i) {
    $month = 5;
  } elsif ($month =~ /jun/i) {
    $month = 6;
  } elsif ($month =~ /jul/i) {
    $month = 7;
  } elsif ($month =~ /aug/i) {
    $month = 8;
  } elsif ($month =~ /sep/i) {
    $month = 9;
  } elsif ($month =~ /oct/i) {
    $month = 10;
  } elsif ($month =~ /nov/i) {
    $month = 11;
  } elsif ($month =~ /dec/i) {
    $month = 12;
  } else {
    die;
  }
  return $month;
}

sub get_date_year {
  my $date = shift;
  if ($date =~ /^(\d+)\/(\d+)\/(\d+)$/) {
    return $3;
  } else {
    die;
  }
}

# Remove commas from quantity if they exist
sub fmt_qty {
  my $qty = shift;
  $qty =~ s/,//g;
  return $qty;
}

sub fmt_symbol {
  my $symbol = shift;
  # BCE 15JAN27 34 C
  if ($symbol =~ /(\w+)\s+(\w+)\s+(\S+)\s+(C|P)/i) {
    my ($ticker,$expiry,$strike,$putcall) = ($1,$2,$3,$4);

    my $date = convert_date($expiry);
    if ($date =~ m#(\d+)/(\d+)/(\d+)#) {
      my ($m,$d,$y) = ($1,$2,$3);
      $m = sprintf("%02d",$m);
      $d = sprintf("%02d",$d);
      $y = sprintf("%02d",$y);

      $strike = sprintf("%08d",1000*$strike);

      if ($putcall =~ /P/i) {
        $putcall = "PUT";
      } else {
        $putcall = "CALL";
      }
      return "${ticker}${y}${m}${d}${putcall}${strike}";

    } else {
      die "Error: Can't get option date from '$symbol' with expiry '$expiry'\n";
    }

  } else {
    return $symbol;
  }
}

1;
