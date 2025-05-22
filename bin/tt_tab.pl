#!/usr/bin/env perl
use warnings;
use strict;
use File::Basename;
use Getopt::Long;
my %OPT;
GetOptions(\%OPT,"header","right","box");

if (@ARGV) {
  my $args = "";
  $args .= " -header" if (exists $OPT{header});
  $args .= " -right" if (exists $OPT{right});
  $args .= " -box" if (exists $OPT{box});
  foreach my $file (@ARGV) {
    system("/bin/cat $file | $0 $args > $file.tmp");
    rename("$file.tmp",$file);
  }

} else {

  my @buf;
  my %db;
  my $num_cols = 0;

  my $line = 0;
  while (<>) {
    chomp;
    $line++;

    # Remove 
    s/\s\|\s/ /g;         # Box
    s/^\s*\|\s/ /g;       # Box
    s/\s\|\s*$/ /g;       # Box
    s/^\s*[\+\-]+\s*$//g; # Box

    s/\*\w+//g;           # Header

    s/^\s+//g;
    s/\s*$//;
    next unless (/\S/);

    push @buf,$_;

    my @bits = split(/\s+/);
    my $num = scalar @bits;
    $num_cols = $num if ($num > $num_cols);

    for (my $i=0; $i<@bits; $i++) {
      my $len = length $bits[$i];
      $db{$i} = $len if (!exists $db{$i} || $len > $db{$i});
    }
  }

  my $total_len = 0;
  foreach my $key (keys %db) {
    $total_len += $db{$key};
  }
  $total_len += 3*$num_cols-1;

  # Optionally add a header that numbers each column
  if (exists $OPT{header}) {
    my $str = "";
    for (my $i=1; $i<=$num_cols; $i++) {
      $str .= "*$i ";
    }
    unshift @buf, $str;
  }

  my $box_str = "+";
  if (exists $OPT{box}) {
    for (my $i=0; $i<$num_cols; $i++) {
      $box_str .= "-" x $db{$i};
      $box_str .= "--+";
    }
    print "$box_str\n";
  }

  $line = 0;
  foreach (@buf) {
    $line++;

    my @bits = split(/\s+/);
    my $buff = "";

    $buff = "| " if (exists $OPT{box});

    for (my $i=0; $i<@bits; $i++) {
      if (exists $OPT{right}) {
        $buff .= sprintf("%$db{$i}s",$bits[$i]);
      } else {
        $buff .= sprintf("%-$db{$i}s",$bits[$i]);
      }
      if (exists $OPT{box}) {
        $buff .= " | " 
      } else {
        $buff .= " ";
      }
    }

    $buff =~ s/\s+$//;
    print "$buff\n";
  }

  if (exists $OPT{box}) {
    print "$box_str\n";
  }
}
