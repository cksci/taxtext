#!/usr/bin/env perl
use strict;
use warnings;
use LWP::UserAgent;
use JSON;

# Replace with your real Alpha Vantage API key
my $api_key = $ENV{ALPHA_VANTAGE_API_KEY};

# Get the ticker symbol from the command line
my $symbol = uc(shift @ARGV || '');
if (!$symbol) {
    die "Usage: $0 TICKER\n";
}

# Construct the Alpha Vantage URL
my $url = "https://www.alphavantage.co/query?function=GLOBAL_QUOTE&symbol=$symbol&apikey=$api_key";

# Set up the user agent
my $ua = LWP::UserAgent->new;
my $response = $ua->get($url);

# Handle errors
die "HTTP request failed: " . $response->status_line unless $response->is_success;

# Decode JSON
my $json = decode_json($response->decoded_content);

# Check for valid response
unless (exists $json->{'Global Quote'}) {
    die "Error: Invalid or empty response from Alpha Vantage.\n";
}

my $quote = $json->{'Global Quote'};

# Display info
print "Symbol:              $quote->{'01. symbol'}\n";
print "Price:               \$$quote->{'05. price'}\n";
print "Open:                \$$quote->{'02. open'}\n";
print "High:                \$$quote->{'03. high'}\n";
print "Low:                 \$$quote->{'04. low'}\n";
print "Volume:              $quote->{'06. volume'}\n";
print "Latest Trading Day:  $quote->{'07. latest trading day'}\n";
print "Previous Close:      \$$quote->{'08. previous close'}\n";
print "Change:              $quote->{'09. change'}\n";
print "Change Percent:      $quote->{'10. change percent'}\n";
