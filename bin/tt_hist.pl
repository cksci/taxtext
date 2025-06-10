#!/usr/bin/env perl
use warnings;
use strict;
use File::Basename;
use POSIX;
my $BASE = basename($0);
my $DIR = dirname($0);

my $USAGE = "$BASE [-bin_count <number>] [-width <number>] [-bin_delta <number>]";
my %OPT = (bin_count=>20, width=>40);
use Getopt::Long;
GetOptions(
  \%OPT,
  "bin_count=i",
  "bin_delta=f",
  "width=i",
  "help"
) || die $USAGE;
die $USAGE if (exists $OPT{help});

my @data_org;
my @data;
while (<>) {
  s/#.*//g;
  if (/^\s*([\d\.\+\-e]+)/) {
    push @data_org,$1;
  }
}

if (@data_org > 0) {
  my @data = sort {$a<=>$b} @data_org;

  my $min = $data[0];
  my $max = $data[$#data];
  my $delta = $max-$min;
  my $bin_count = $OPT{bin_count};
  my $bin_delta = $delta/$bin_count+0;

  my $digits = 6;
  if ($max > 1) {
    $digits = 3;
    if ($max > 100) {
      $digits = 2;
    }
  }

  if (exists $OPT{bin_delta}) {
    $bin_delta = $OPT{bin_delta};
    $bin_count = ceil($delta/$bin_delta);
  }

  my $mid = floor($#data/2);
  my $mean = $data[$mid];

  my $tot = 0;
  my $tot_dev = 0;
  my $i = 0;
  foreach my $d (@data) {
    $tot += $d;
    $tot_dev += ($d-$mean)**2;
    $i++;
  }
  my $avg = $tot/$i+0;
  my $stdev = ($tot_dev/$i)**0.5;

  $bin_delta = abs($max) if (abs($bin_delta) < 1e-6);
  $bin_delta = 0.001     if (abs($bin_delta) < 1e-6);
  $bin_delta += 0;

  my @hist;
  foreach (my $i=0; $i<$bin_count; $i++) {
    $hist[$i] = 0;
  }

  foreach my $d (@data) {
    my $bin = floor(($d-$min)/$bin_delta);
    $hist[$bin]++;
  }

  my $max_count = 0;
  foreach (my $i=0; $i<$bin_count; $i++) {
    $max_count = $hist[$i] if ($hist[$i] > $max_count);
  }

  print "Datas = " . scalar(@data) . "\n";
  print "First = " . sprintf("%.${digits}f",$data_org[0]) . "\n";
  print "Last  = " . sprintf("%.${digits}f",$data_org[$#data_org]). "\n";
  print "Min   = " . sprintf("%.${digits}f",$min). "\n";
  print "Max   = " . sprintf("%.${digits}f",$max). "\n";
  print "Avg   = " . sprintf("%.${digits}f",$avg). "\n";
  print "Mean  = " . sprintf("%.${digits}f",$mean). "\n";
  print "Stdev = " . sprintf("%.${digits}f",$stdev). "\n";
  print "Range = " . sprintf("%.${digits}f",$delta). "\n";
  print "Bins  = $bin_count\n";
  print "Delta = $bin_delta\n";
  open(OUT,"|tabulate.pl") || die "Error: Can't pipe to 'tabulate.pl': $!\n";

  my $tot_pct = 0;
  foreach (my $i=0; $i<$bin_count; $i++) {
    my $lo = $min+$bin_delta*$i+0;
    my $hi = $min+$bin_delta*($i+1);
    my $pct = sprintf("%.2f",100.0*$hist[$i]/scalar(@data));
    $tot_pct = sprintf("%.2f",$pct+$tot_pct);
    print OUT $i+1 . ": $lo -> $hi $hist[$i] ( $pct% $tot_pct% ) | ";
    my $chars = floor($OPT{width}*$hist[$i]/$max_count);
    print OUT "*" x$chars;
    print OUT "\n";
  }
}
