#!/usr/bin/env python3
import requests
import sys

# Replace with your Finnhub API key
API_KEY = 'd0d73u9r01qm2sk8dtsgd0d73u9r01qm2sk8dtt0'

# Get ticker symbol from command line
symbol = sys.argv[1] if len(sys.argv) > 1 else 'AAPL'

# Finnhub quote endpoint
url = f'https://finnhub.io/api/v1/quote?symbol={symbol}&token={API_KEY}'

# Send request
response = requests.get(url)

# Handle response
if response.status_code != 200:
    print(f"Error: {response.status_code} - {response.text}")
    sys.exit(1)

data = response.json()

# Print basic quote info
print(f"Symbol: {symbol}")
print(f"Current Price: ${data['c']}")
print(f"Open Price:    ${data['o']}")
print(f"High Price:    ${data['h']}")
print(f"Low Price:     ${data['l']}")
print(f"Previous Close:${data['pc']}")
