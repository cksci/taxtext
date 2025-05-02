#!/usr/bin/env perl
use warnings;
use strict;
use LWP::UserAgent;
use JSON;

my $api_key = $ENV{ALPHA_VANTAGE_API_KEY};
my $symbol = 'AAPL';
my $url = "https://www.alphavantage.co/query?function=TIME_SERIES_DAILY&symbol=$symbol&apikey=$api_key";

my $ua = LWP::UserAgent->new;
my $response = $ua->get($url);

if ($response->is_success) {
    my $data = decode_json($response->decoded_content);
    # Process the data as needed
use Data::Dumper;
print Dumper($data);
} else {
    warn "Failed to fetch data: ", $response->status_line;
}
