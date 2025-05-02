#!/usr/bin/env python3

import yfinance as yf
import argparse
import warnings
import re
from datetime import datetime, timedelta

def get_usdcad():
    ticker = yf.Ticker("USDCAD=X")
    return ticker.history(period="1d")['Close'].iloc[-1]

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
    print("HEADER ACCOUNT STATUS RISK SECTOR SYMBOL CURRENCY QUANTITY COST PRICE CHANGE_PCT GAIN_PCT DIV YIELD DIV_TOT DIV_TOT_CAD BOOK VALUE GAIN BOOK_CAD VALUE_CAD GAIN_CAD")

    for line in data:

        command    = line[0]
        if command == 'HEADER':
            continue

        account    = line[1]
        status     = line[2]
        risk       = line[3]
        sector     = line[4]
        symbol     = line[5]
        currency   = line[6]
        quantity   = float(line[7])
        cost       = float(line[8])
        price      = line[9]
        change_pct = line[10]
        gain_pct   = line[11]
        dividend   = line[12]
        div_yield  = line[13]
        book       = line[14]
        value      = line[15]
        gain       = line[16]
        book_cad   = line[17]
        value_cad  = line[18]
        gain_cad   = line[19]

        symbol2, n = re.subn(r'\.CAD', '', symbol)
        if n > 0:
            symbol2 += '.TO'
        else:
            symbol2, n = re.subn(r'\.USD', '', symbol)


        match = re.search(r"(CALL|PUT)", symbol2)
        if match:
          continue

        #print(f"{symbol2} debug")
        #continue

        usdcad    = get_usdcad()
        stock     = yf.Ticker(symbol2)
        dividends = stock.dividends

        # Remove time zone
        dividends.index = dividends.index.tz_localize(None)

        new_sector = stock.info.get("sectorKey", None)
        if new_sector is None:
          new_sector = sector

        new_book  = quantity*cost
        new_price = stock.info.get("currentPrice", None)
        if new_price is None:
          new_price = stock.info.get("regularMarketPreviousClose", None)

        new_div   = stock.info.get("dividendRate", None)

        if new_div is None:
          one_year_ago = datetime.now() - timedelta(days=365)
          recent_dividends = dividends[dividends.index > one_year_ago]
          new_div = recent_dividends.sum()

        new_div_yield = 100*new_div/new_price
        new_div_tot   = quantity*new_div

        currency     = stock.info.get("currency", None)
        new_value    = quantity*new_price
        new_gain     = new_value-new_book
        new_gain_pct = 100*(new_value/new_book-1)

        new_book_cad    = usdcad*new_book
        new_value_cad   = usdcad*new_value
        new_gain_cad    = usdcad*new_gain
        new_div_tot_cad = usdcad*new_div_tot
        print(f"HOLD {account} {status} {risk} {new_sector} {symbol2} {currency} {quantity:.3f} {cost:.3f} {new_price:.3f} {change_pct} {new_gain_pct:.3f} {new_div:.3f} {new_div_yield:.3f} {new_div_tot:.3f} {new_div_tot_cad:.3f} {new_book:.3f} {new_value:.3f} {new_gain:.3f} {new_book_cad:.3f} {new_value_cad:.3f} {new_gain_cad:.3f}")

parser = argparse.ArgumentParser()
parser.add_argument("file", type=str, help="ttxt portfolio")
args = parser.parse_args()

update_db(args.file)
