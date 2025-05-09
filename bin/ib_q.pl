#!/usr/bin/env python3

from ib_insync import *
import sys
import re
import math
import xml.etree.ElementTree as ET

# Connect to TWS
ib = IB()
ib.connect('127.0.0.1', 7497, clientId=1)

# Check symbol argument
if len(sys.argv) < 2:
    print("Usage: python ibkr_get_price_and_dividend.py SYMBOL")
    print("Examples:")
    print("  US stock:        AAPL")
    print("  Canadian stock:  TD.TO")
    print("  US option:       AAPL250920C00125000")
    print("  CA option:       BCE270115C00033000")
    sys.exit(1)

symbol_input = sys.argv[1].upper()
occ_pattern = re.compile(r'^([A-Z\.]+)(\d{6})([CP])(\d{8})$')

# === OCC-style Option Symbol ===
if occ_pattern.match(symbol_input):
    m = occ_pattern.match(symbol_input)
    underlying_raw, date, right, strike_str = m.groups()

    year = int('20' + date[:2])
    month = int(date[2:4])
    day = int(date[4:6])
    expiry = f"{year}{month:02d}{day:02d}"
    strike = int(strike_str) / 1000

    if underlying_raw.endswith('.TO'):
        underlying = underlying_raw.replace('.TO', '')
        exchange = 'MX'
        currency = 'CAD'
    else:
        underlying = underlying_raw
        exchange = 'SMART'
        currency = 'USD'

    contract = Option(
        symbol=underlying,
        lastTradeDateOrContractMonth=expiry,
        strike=strike,
        right=right,
        exchange=exchange,
        tradingClass=underlying,
        currency=currency
    )

    ib.qualifyContracts(contract)

    print(f"Option: {symbol_input} → {underlying} {right} ${strike:.2f} exp {expiry} ({exchange})")

    ticker = ib.reqMktData(contract, '', False, False)
    ib.sleep(1)
    print(f"Last price: {ticker.last}")

# === Stock Symbol ===
else:
    if symbol_input.endswith('.TO'):
        symbol = symbol_input.replace('.TO', '')
        contract = Stock(symbol, 'TSE', 'CAD')
    else:
        symbol = symbol_input
        contract = Stock(symbol, 'SMART', 'USD')

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

    print(f"Stock: {symbol_input}")
    print(f"Last price: {price}")
    print(f"Trailing 12M Dividend: {dividend}")

ib.disconnect()
