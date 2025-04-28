#!/usr/bin/env python3
import yfinance as yf
from datetime import datetime, timedelta

# Define the currency pair
ticker = "USDCAD=X"

# Get the date range (last year)
end_date = datetime.today().strftime('%Y-%m-%d')
start_date = (datetime.today() - timedelta(days=2000)).strftime('%Y-%m-%d')

# Fetch historical data
data = yf.download(ticker, start=start_date, end=end_date)

# Drop rows with missing close prices
data = data[['Close']].dropna()

for date, row in data.iterrows():
    close_price = float(row['Close'])  # Convert to float if necessary
    print(f"{date.strftime('%-m/%-d/%Y')} {close_price:.4f}")
