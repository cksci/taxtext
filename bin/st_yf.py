#!/usr/bin/env python3

import yfinance as yf
import argparse
import warnings
import re
import sys
from datetime import datetime, timedelta

## ticker_symbol = "JPM"  # Make sure it's only one ticker
## start_date = "2024-01-01"
## 
## stock_data = yf.download(ticker_symbol, start=start_date, auto_adjust=False, group_by='columns')
## 
## print(stock_data.head())
## print("hi")
## print(stock_data.columns)

parser = argparse.ArgumentParser()
parser.add_argument("file", type=str, help="SplitCorp NAV st")
args = parser.parse_args()

pattern = re.compile(r"^WEIGHT (\d{2}/\d{2}/\d{4}) (\w+)\s+([\d.]+)$")
start_date = "2023-11-30"

# Open and read the file line by line
with open(args.file, 'r') as file:
    for line in file:
        line = line.strip()
        match = pattern.match(line)
        if match:
            date_str, symbol , weight = match.groups()
            print(f"Date: {date_str}, Ticker: {symbol}, Weight: {weight}")

            if symbol != "CASH":
                stock_data = yf.download("JPM", start=start_date, auto_adjust=False)

                for date, row in stock_data.iterrows():
                    close_price = row['Close']
                    print(f"{date.strftime('%Y-%m-%d')}: {close_price:.2f}")
