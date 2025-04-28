#!/usr/bin/env perl
use warnings;
use strict;
use File::Basename;
use Getopt::Long;
my %OPT;
GetOptions(\%OPT,"sum","header","clean","right");

my $SCRIPT = basename($0);

if (@ARGV) {
  my $args = "";
  $args .= " -sum" if (exists $OPT{sum});
  $args .= " -header" if (exists $OPT{header});
  $args .= " -clean" if (exists $OPT{clean});
  $args .= " -right" if (exists $OPT{right});
  foreach my $file (@ARGV) {
    system("/bin/cat $file | $SCRIPT $args > $file.tmp");
    rename("$file.tmp",$file);
  }
} else {
  my @buf;
  my %db;
  my %com;
  my $num_cols = 0;

  my $line = 0;
  while (<>) {
    chomp;
    $line++;

    s/^\s+//g;
    s/\s*$//;
    if (s/\s*(\/\/.*)//) {
      $com{$line} = $1;
    }
    s/(\.\d+?)0+\b/$1/g if (exists $OPT{clean});
    push @buf,$_;

    my @bits = split(/\s+/);
    my $num = scalar @bits;
    $num_cols = $num if ($num > $num_cols);
    for (my $i=0; $i<@bits; $i++) {
      my $len = length $bits[$i];
      $db{$i} = $len if (!exists $db{$i} || $len > $db{$i});
    }
  }

  if (exists $OPT{header}) {
    my $str = "#";
    for (my $i=1; $i<=$num_cols; $i++) {
      $str .= "$i ";
    }
    unshift @buf, $str;
  }

  $line = 0;
  foreach (@buf) {
    $line ++;

    if (/^\s*\/\//) {
      print;
    } else {
      my @bits = split(/\s+/);
      my $buff = "";
      for (my $i=0; $ i<@bits; $i++) {
        if ($i == $#bits) {
          if (exists $OPT{right}) {
            $buff .= sprintf("%$db{$i}s",$bits[$i]);
          } else {
            $buff .= sprintf("%-$db{$i}s",$bits[$i]);
          }
        } else {
          if (exists $OPT{right}) {
            $buff .= sprintf("%$db{$i}s ",$bits[$i]);
          } else {
            $buff .= sprintf("%-$db{$i}s ",$bits[$i]);
          }
        }
        $num_cols = $i if ($i>$num_cols);
      }

      if (exists $com{$line}) {
        $buff .= "$com{$line}";
      }
      $buff =~ s/\s+$//;
      print "$buff\n";
    }
  }

  $num_cols++;
  warn "$num_cols colums\n" if (exists $OPT{sum});
}
