#!/usr/bin/env python3

from ib_insync import *
import sys
import re
import math
import xml.etree.ElementTree as ET

# Connect to TWS or IB Gateway
ib = IB()
ib.connect('127.0.0.1', 7497, clientId=1)

# Check input
if len(sys.argv) < 2:
    print("Usage: python ibkr_get_price_and_dividend.py SYMBOL")
    sys.exit(1)

original_input = sys.argv[1].strip().upper()
is_canadian = original_input.endswith('.TO')

# Normalize symbol
symbol_clean = original_input.replace('.TO', '')

# OCC-style regex: UNDERLYING + YYMMDD + C/P + STRIKE
occ_pattern = re.compile(r'^([A-Z]+)(\d{6})([CP])(\d{8})$')
occ_match = occ_pattern.match(symbol_clean)

# === OCC-STYLE OPTION ===
if occ_match:
    underlying, date, right, strike_str = occ_match.groups()

    year = int('20' + date[:2])
    month = int(date[2:4])
    day = int(date[4:6])
    expiry = f"{year}{month:02d}{day:02d}"
    strike = int(strike_str) / 1000

    # Exchange and currency logic
    if is_canadian:
        exchange = 'CDE'
        currency = 'CAD'
        trading_class = underlying  # e.g., 'BCE'
    else:
        exchange = 'SMART'
        currency = 'USD'
        trading_class = ''

    contract = Option(
        symbol=underlying,
        lastTradeDateOrContractMonth=expiry,
        strike=strike,
        right=right,
        exchange=exchange,
        currency=currency,
        tradingClass=trading_class
    )

    try:
        ib.qualifyContracts(contract)
        print(f"Option: {original_input} → {underlying} {right} ${strike:.2f} exp {expiry} ({exchange})")
        ticker = ib.reqMktData(contract, '', False, False)
        ib.sleep(1)
        print(f"Last price: {ticker.last}")
    except Exception as e:
        print(f"⚠️ Error with option contract: {e}")

# === STOCK SYMBOL ===
else:
    if is_canadian:
        symbol = symbol_clean
        contract = Stock(symbol, 'TSE', 'CAD')
    else:
        symbol = symbol_clean
        contract = Stock(symbol, 'SMART', 'USD')

    try:
        ib.qualifyContracts(contract)
        ticker = ib.reqMktData(contract, '', False, False)
        ib.sleep(1)

        dividend = "N/A"
        try:
            report = ib.reqFundamentalData(contract, 'ReportSnapshot')
            ib.sleep(1)
            if report:
                root = ET.fromstring(report)
                dividend = root.findtext('.//Trailing12MDividend') or "N/A"
        except:
            pass

        price = ticker.last if ticker.last and not math.isnan(ticker.last) else ticker.close
        print(f"Stock: {original_input}")
        print(f"Last price: {price}")
        print(f"Trailing 12M Dividend: {dividend}")
    except Exception as e:
        print(f"⚠️ Error with stock contract: {e}")

ib.disconnect()
