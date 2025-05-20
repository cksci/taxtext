#!/usr/bin/env python3

import yfinance as yf
import argparse
import warnings
import re
import sys
from datetime import datetime, timedelta

def get_usdcad():
    ticker = yf.Ticker("USDCAD=X")
    return ticker.history(period="3d")['Close'].iloc[-1]

def read_db(file_path):

    data = []
    try:
        with open(file_path, 'r') as file:
            for line in file:
                if line.strip().startswith('#'):
                    continue
                values = line.split()
                data.append(values)
    except FileNotFoundError:
        print(f"Error: File not found at {file_path}")
    except Exception as e:
        print(f"An error occurred: {e}")
    
    return data

def update_db(file_path):
    
    data = read_db(file_path)
    print("HEADER ACCOUNT SYMBOL SYMBOL_YAHOO CURRENCY STATUS RISK SECTOR TYPE QUANTITY COST PRICE CHANGE GAIN_PCT DIV YIELD DIV_TOT DIV_TOT_CAD BOOK VALUE GAIN BOOK_CAD VALUE_CAD GAIN_CAD")

    for line in data:

        # TODO: Update to auto determine column indexes
        command    = line[0]
        if command == 'HEADER':
            continue

        account      = line[1]
        symbol       = line[2]
        symbol_yahoo = line[3]
        currency     = line[4]
        status       = line[5]
        risk         = line[6]
        sector       = line[7]
        type         = line[8]
        qty          = float(line[9])
        cost         = float(line[10])
        price        = float(line[11])
        change       = float(line[12])
        gain_pct     = float(line[13])
        div          = float(line[14])
        yield_pct    = float(line[15])
        div_tot      = float(line[16])
        div_tot_cad  = float(line[17]) 
        book         = float(line[18]) 
        value        = float(line[19]) 
        gain         = float(line[20]) 
        book_cad     = float(line[21]) 
        value_cad    = float(line[22]) 
        gain_cad     = float(line[23])

        backup = f"HOLD {account} {symbol} {symbol_yahoo} {currency} {status} {risk} {sector} {type} {qty:.4f} {cost:.4f} {price:.4f} {change} {gain_pct:.4f} {div:.4f} {yield_pct:.4f} {div_tot:.4f} {div_tot_cad:.4f} {book:.4f} {value:.4f} {gain:.4f} {book_cad:.4f} {value_cad:.4f} {gain_cad:.4f}"

        usdcad = get_usdcad()
        stock  = yf.Ticker(symbol_yahoo)
        try:
            info = stock.info
            if not info or 'regularMarketPrice' not in info:
                print(f"# Warning: No data for symbol {symbol_yahoo}", file=sys.stderr)
                print(f"{backup}")
                continue
        except Exception as e:
            print(f"# Warning: No data for symbol {symbol_yahoo}", file=sys.stderr)
            print(f"{backup}")
            continue

        dividends       = stock.dividends
        dividends.index = dividends.index.tz_localize(None)

        new_sector = sector
        try:
            new_sector = stock.info.get("sectorKey", None)
            if new_sector is None:
                underlying = stock.info.get("underlyingSymbol", None)
                if underlying is None:
                    new_sector = sector
                else:
                    stock2 = yf.Ticker(underlying)
                    new_sector = stock2.info.get("sectorKey", None)
                    if new_sector is None:
                        new_sector = sector
        except Exception as e:
            print(f"# Info: Can't get symbol {symbol_yahoo} sectorKey attribute", file=sys.stderr)

        new_type = type
        try:
            new_type = stock.info.get("quoteType", None)
            if new_type is None:
                new_type = type
            if new_type != type:
                print(f"# Info: Type changed from {type} to {new_type} for symbol {symbol_yahoo}", file=sys.stderr)
        except Exception as e:
            print(f"# Info: Can't get symbol {symbol_yahoo} quoteType attribute", file=sys.stderr)

        new_book  = qty*cost

        new_price = price
        try:
            new_price = stock.info.get("regularMarketPrice", None)
            if new_price is None:
                new_price = stock.info.get("currentPrice", None)
                if new_price is None:
                    new_price = stock.info.get("regularMarketPreviousClose", None)
        except Exception as e:
            print(f"# Info: Can't get symbol {symbol_yahoo} price attribute", file=sys.stderr)

        new_change = new_price-cost
        if price > 0 and abs(new_price/price) > 1.005:
          print(f"# Info: Price changed from {price:.4f} to {new_price:.4f} for symbol {symbol_yahoo}", file=sys.stderr)

        new_div = div
        try:
            new_div = stock.info.get("dividendRate", None)
            if new_div is None:
                one_year_ago = datetime.now() - timedelta(days=365)
                recent_dividends = dividends[dividends.index > one_year_ago]
                new_div = recent_dividends.sum()
        except Exception as e:
            print(f"# Info: Can't get symbol {symbol_yahoo} dividendRate attribute", file=sys.stderr)

        if sector != new_sector:
            print(f"# Info: Sector changed from {sector} to {new_sector} for symbol {symbol_yahoo}", file=sys.stderr)

        if abs(new_div-div) > 1e-3:
            print(f"# Info: Dividend changed from {div:.4f} to {new_div:.4f} for symbol {symbol_yahoo}", file=sys.stderr)

        new_yield_pct = 100.0*new_div/new_price
        new_div_tot   = qty*new_div

        new_currency = currency
        try:
            currency     = stock.info.get("currency", None)
            new_value    = qty*new_price
            new_gain     = new_value-new_book
            new_gain_pct = 100.0*(new_value/new_book-1)
        except Exception as e:
            print(f"# Info: Can't get symbol {symbol_yahoo} currency attribute", file=sys.stderr)

        new_book_cad    = new_book
        new_value_cad   = new_value
        new_gain_cad    = new_gain
        new_div_tot_cad = new_div_tot

        if new_currency == "USD":
            new_book_cad    = usdcad*new_book
            new_value_cad   = usdcad*new_value
            new_gain_cad    = usdcad*new_gain
            new_div_tot_cad = usdcad*new_div_tot

        if sector == "crypto" or new_type == "CRYPTOCURRENCY":
            print(f"HOLD {account} {symbol} {symbol_yahoo} {new_currency} {status} {risk} {new_sector} {new_type} {qty:.8f} {cost:.4f} {new_price:.4f} {new_change:.4f} {new_gain_pct:.4f} {new_div:.4f} {new_yield_pct:.4f} {new_div_tot:.4f} {new_div_tot_cad:.4f} {new_book:.4f} {new_value:.4f} {new_gain:.4f} {new_book_cad:.4f} {new_value_cad:.4f} {new_gain_cad:.4f}")
        else:
            print(f"HOLD {account} {symbol} {symbol_yahoo} {new_currency} {status} {risk} {new_sector} {new_type} {qty:.4f} {cost:.4f} {new_price:.4f} {new_change:.4f} {new_gain_pct:.4f} {new_div:.4f} {new_yield_pct:.4f} {new_div_tot:.4f} {new_div_tot_cad:.4f} {new_book:.4f} {new_value:.4f} {new_gain:.4f} {new_book_cad:.4f} {new_value_cad:.4f} {new_gain_cad:.4f}")

parser = argparse.ArgumentParser()
parser.add_argument("file", type=str, help="ttxt portfolio")
args = parser.parse_args()

update_db(args.file)
