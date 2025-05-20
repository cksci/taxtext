package Tax::Txt;

use strict;
use warnings;

use Exporter qw(import);
our @EXPORT = qw(fmt_money fmt_money2 map_ticker calc_fee convert_date month_num get_date_year fmt_qty fmt_symbol tt_parse_header tt_is_option tt_parse_cost_line tt_get_latest_date tt_get_date tt_make_yahoo_symbol );

sub fmt_money {
  my $value = shift;
  my $digs = shift;
  $digs = 5 if (!defined $digs);
  $value =~ s/,//g;
  $value =~ s/"//g;
  return sprintf("%.${digs}f",$value);
}

sub fmt_money2 {
  my $number = shift;
  my $digs = shift;
  $digs = 2 if (!defined $digs);
  $number =~ s/,//g;
  $number = sprintf("%.${digs}f",$number);
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
    $day =~ s/^0//g;
    $month =~ s/^0//g;
    return "$month/$day/$year";

  } elsif ($str =~ /^\s*(\d+)\-([a-z]+)\-(\d+)/i) {

    my ($day,$month,$year) = ($1,$2,$3);
    $year += 2000 if ($year < 2000);
    $month = month_num($month);
    $day =~ s/^0//g;
    $month =~ s/^0//g;
    return "$month/$day/$year";

  } elsif ($str =~ /^\s*(\d+)\-(\d+)\-(\d+)/i) {

    my ($year,$month,$day) = ($1,$2,$3);
    $day =~ s/^0//g;
    $month =~ s/^0//g;
    return "$month/$day/$year";

  } elsif ($str =~ /^\s*(\d+)\/(\d+)\/(\d+)/) {
    my ($month,$day,$year) = ($1,$2,$3);
    $day =~ s/^0//g;
    $month =~ s/^0//g;
    return "$month/$day/$year";

  } elsif ($str =~ /^\s*(\d+)([a-zA-Z]+)(\d+)\s*/) {
    # BCE 15JAN27 34 C
    my ($day,$month,$year) = ($1,$2,$3);
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
  if ($symbol =~ /(\S+)\s+(\w+)\s+(\S+)\s+(C|P)/i) {
    my ($ticker,$expiry,$strike,$putcall) = ($1,$2,$3,$4);
    $ticker =~ s/\.\w+//; # Ex. RCI.B => RCI

    my $date = convert_date($expiry);
    if ($date =~ m#(\d+)/(\d+)/(\d+)#) {
      my ($m,$d,$y) = ($1,$2,$3);
      $m = sprintf("%02d",$m);
      $d = sprintf("%02d",$d);
      $y = sprintf("%02d",$y);

      $strike = sprintf("%08d",1000*$strike);

      if ($putcall =~ /P/i) {
        $putcall = "P";
      } else {
        $putcall = "C";
      }
      return "${ticker}${y}${m}${d}${putcall}${strike}";

    } else {
      die "Error: Can't get option date from '$symbol' with expiry '$expiry'\n";
    }

  } else {
    return $symbol;
  }
}

sub tt_parse_header {
  my $line = shift;

  chomp($line);
  $line =~ s/^\s+//;
  $line =~ s/\s+$//;

  my %cols;
  my @bits = split(/\s+/,$line);

  for (my $i=0; $i<@bits; $i++) {
    my $col = $bits[$i];
    if ($col eq "HEADER") {
    } elsif ($col eq "ACCOUNT") {
      $cols{$col} = $i;
    } elsif ($col eq "SYMBOL") {
      $cols{$col} = $i;
    } elsif ($col eq "SYMBOL_YAHOO") {
      $cols{$col} = $i;
    } elsif ($col eq "CURRENCY") {
      $cols{$col} = $i;
    } elsif ($col eq "STATUS") {
      $cols{$col} = $i;
    } elsif ($col eq "RISK") {
      $cols{$col} = $i;
    } elsif ($col eq "SECTOR") {
      $cols{$col} = $i;
    } elsif ($col eq "TYPE") {
      $cols{$col} = $i;
    } elsif ($col eq "QUANTITY") {
      $cols{$col} = $i;
    } elsif ($col eq "COST") {
      $cols{$col} = $i;
    } elsif ($col eq "PRICE") {
      $cols{$col} = $i;
    } elsif ($col eq "CHANGE") {
      $cols{$col} = $i;
    } elsif ($col eq "GAIN_PCT") {
      $cols{$col} = $i;
    } elsif ($col eq "DIV") {
      $cols{$col} = $i;
    } elsif ($col eq "YIELD") {
      $cols{$col} = $i;
    } elsif ($col eq "DIV_TOT") {
      $cols{$col} = $i;
    } elsif ($col eq "DIV_TOT_CAD") {
      $cols{$col} = $i;
    } elsif ($col eq "BOOK") {
      $cols{$col} = $i;
    } elsif ($col eq "VALUE") {
      $cols{$col} = $i;
    } elsif ($col eq "GAIN") {
      $cols{$col} = $i;
    } elsif ($col eq "BOOK_CAD") {
      $cols{$col} = $i;
    } elsif ($col eq "VALUE_CAD") {
      $cols{$col} = $i;
    } elsif ($col eq "GAIN_CAD") {
      $cols{$col} = $i;
    } else {
      die "Error: Found unknown column '$col' when parsing header '$line'\n";
    }
  }
  return %cols;
}

sub tt_is_option {
  my $symbol = shift;
  if ($symbol =~ /\w+\d\d\d\d\d\d(C|P)\d\d\d\d\d\d\d\d/) {
    return 1;
  } else {
    return 0;
  }
}

sub tt_parse_cost_line {
  my $line = shift;
  chomp $line;
  $line =~ s/^\s+//;
  $line =~ s/\s+$//;
  my @bits = split(/\s+/,$line);
  # COST 5/14/2025 5/14/2025 NVDA.CAD 1000 CAD 30.89085 0.00000 30890.85000
  return (what=>$bits[0], date=>$bits[1], date_settle=>$bits[2], symbol=>$bits[3], quantity=>$bits[4], currency=>$bits[5], cost=>$bits[6], fee=>$bits[7], cost_total=>$bits[8]);
}

sub tt_get_latest_date {
  my @dates = @_;
  use Time::Local;

  my $latest_date = '';
  my $latest_epoch = 0;

  foreach my $date (@dates) {
    my ($mm, $dd, $yyyy) = split('/', $date);
    my $epoch = timelocal(0, 0, 12, $dd, $mm - 1, $yyyy);

    if ($epoch > $latest_epoch) {
      $latest_epoch = $epoch;
      $latest_date = $date;
    }
  }

  return $latest_date;
}

sub tt_get_date {
  use Time::Local;

  my ($sec,$min,$hour,$mday,$mon,$year) = localtime();
  $mon  += 1;
  $year += 1900;

  return sprintf("%d/%d/%d",$mon,$mday,$year);
}

sub tt_make_yahoo_symbol {
  my $symbol_yahoo = shift;
  $symbol_yahoo =~ s/\.PR\./-P/;
  $symbol_yahoo =~ s/\.UN/-UN/;
  $symbol_yahoo =~ s/\.CAD/.TO/;
  $symbol_yahoo =~ s/\.USD//;
  return $symbol_yahoo;
}

1;
