#!/usr/bin/env python3
import os
import requests
import sys

# Get API key from environment
API_KEY = os.getenv("FINNHUB_API_KEY")

if not API_KEY:
    print("Error: FINNHUB_API_KEY environment variable not set.")
    sys.exit(1)

# Get symbol from CLI or prompt
symbol = sys.argv[1] if len(sys.argv) > 1 else input("Enter ticker (e.g., TD.TO): ").strip().upper()

# Quote endpoint
url = f'https://finnhub.io/api/v1/quote?symbol={symbol}&token={API_KEY}'

# Request data
response = requests.get(url)

# Handle errors
if response.status_code == 403:
    print("Access denied: Your API key may not support this data.")
    sys.exit(1)
elif response.status_code != 200:
    print(f"Error: {response.status_code} - {response.text}")
    sys.exit(1)

data = response.json()

if not data.get("c"):
    print("No quote data returned — possibly unsupported ticker.")
    sys.exit(1)

# Display quote info
print(f"Symbol:           {symbol}")
print(f"Current Price:    ${data['c']}")
print(f"Open Price:       ${data['o']}")
print(f"High Price:       ${data['h']}")
print(f"Low Price:        ${data['l']}")
print(f"Previous Close:   ${data['pc']}")
