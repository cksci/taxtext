#!/usr/bin/env python3
import yfinance as yf
import sys
print(sys.executable)

def get_current_price(ticker_symbol):
    ticker = yf.Ticker(ticker_symbol)
    data = ticker.history(period="1d")
    if data.empty:
        print(f"No data found for {ticker_symbol}")
        return
    latest_price = data['Close'].iloc[-1]
    print(f"Current price of {ticker_symbol}: ${latest_price:.2f}")
    print(data)

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python get_stock_price.py TICKER")
    else:
        get_current_price(sys.argv[1])
