#!/usr/bin/env python3
import yfinance as yf
from datetime import datetime, timedelta
import pandas as pd

# Define the currency pair
ticker = "USDCAD=X"

# Get the date range
end_date = datetime.today().strftime('%Y-%m-%d')
start_date = (datetime.today() - timedelta(days=2000)).strftime('%Y-%m-%d')

# Fetch historical trading data
data = yf.download(ticker, start=start_date, end=end_date)

# Keep only the 'Close' column and drop NaNs (from non-trading days)
data = data[['Close']].dropna()

# Generate all calendar dates in the range
calendar_index = pd.date_range(start=data.index.min(), end=data.index.max(), freq='D')

# Reindex to include all calendar days
data = data.reindex(calendar_index)

# Forward-fill missing values (non-trading days)
data.ffill(inplace=True)

# Output in mm/dd/yyyy format
for date, row in data.iterrows():
    close_price = float(row['Close'])
    print(f"{date.strftime('%-m/%-d/%Y')} {close_price:.4f}")

# Fetch recent USD/CAD exchange rate data
ticker = yf.Ticker("USDCAD=X")
data = ticker.history(period="1d", interval="1m")  # 1-minute data for today

# Get the latest available value
latest_price = data['Close'].iloc[-1]

# Get the current date and time
now = datetime.now().strftime('%-m/%-d/%Y')
print(f"{now} {latest_price:.4f}")
