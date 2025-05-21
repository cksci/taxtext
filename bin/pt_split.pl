#!/usr/bin/env perl
use warnings;
use strict;

my $awp = $ARGV[0];

system("pt_export.pl -sa $awp | grep :US > LongUSD_SA.csv");
system("pt_export.pl -sa $awp | grep -v :US > LongCAD_SA.csv");
system("pt_export.pl -sa -options_only $awp | grep :US > OptionsUSD_SA.csv");
system("pt_export.pl -sa -options_only $awp | grep -v :US > OptionsCAD_SA.csv");

system("pt_export.pl -tv $awp > Long_TV.csv");
system("pt_export.pl -tv -options_only $awp > Options_TV.csv");

system("pt_export.pl -fg $awp > Long_FG.csv");
system("pt_export.pl -fg -options_only $awp > Options_FG.csv");
