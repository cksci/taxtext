#!/usr/bin/env perl
use warnings;
use strict;
use Finance::Quote;

my $q = Finance::Quote->new();
my %info = $q->fetch('yahoo_json', 'ARCC');

if ($info{'ARCC', 'success'}) {
    print "Price: $info{'ARCC', 'last'}\n";
} else {
    warn "Failed to fetch quote for ARCC\n";
}
use Data::Dumper;
print Dumper(\%info);
