"""Publish stock ticks to Kinesis from demo data or Alpha Vantage."""

from __future__ import annotations

import argparse
import json
import os
import random
import time
import urllib.parse
import urllib.request
from datetime import UTC, datetime

import boto3


def demo_quote(symbol: str, prior: float) -> dict:
    price = round(max(0.01, prior * (1 + random.uniform(-0.003, 0.003))), 2)
    return {
        "symbol": symbol,
        "price": price,
        "volume": random.randint(100, 100_000),
        "timestamp": datetime.now(UTC).isoformat().replace("+00:00", "Z"),
        "source": "demo",
    }


def alpha_vantage_quote(symbol: str, api_key: str) -> dict:
    query = urllib.parse.urlencode(
        {"function": "GLOBAL_QUOTE", "symbol": symbol, "apikey": api_key}
    )
    with urllib.request.urlopen(f"https://www.alphavantage.co/query?{query}", timeout=15) as response:
        quote = json.load(response).get("Global Quote", {})
    if not quote.get("05. price"):
        raise RuntimeError("Alpha Vantage returned no quote; check the key or rate limit")
    return {
        "symbol": symbol,
        "price": float(quote["05. price"]),
        "volume": int(quote["06. volume"]),
        "timestamp": datetime.now(UTC).isoformat().replace("+00:00", "Z"),
        "source": "alpha-vantage",
    }


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--stream", required=True)
    parser.add_argument("--symbols", default="AAPL,AMZN,MSFT")
    parser.add_argument("--interval", type=float, default=5)
    parser.add_argument("--count", type=int, default=0, help="0 streams until interrupted")
    parser.add_argument("--provider", choices=("demo", "alpha-vantage"), default="demo")
    parser.add_argument("--region", default=os.getenv("AWS_REGION"))
    args = parser.parse_args()

    api_key = os.getenv("ALPHA_VANTAGE_API_KEY", "")
    if args.provider == "alpha-vantage" and not api_key:
        parser.error("ALPHA_VANTAGE_API_KEY is required for alpha-vantage")
    client = boto3.client("kinesis", region_name=args.region)
    prices = {symbol: random.uniform(80, 300) for symbol in args.symbols.upper().split(",")}
    sent = 0
    try:
        while args.count == 0 or sent < args.count:
            for symbol, previous_price in prices.items():
                tick = (
                    demo_quote(symbol, previous_price)
                    if args.provider == "demo"
                    else alpha_vantage_quote(symbol, api_key)
                )
                prices[symbol] = tick["price"]
                client.put_record(
                    StreamName=args.stream,
                    PartitionKey=symbol,
                    Data=json.dumps(tick).encode(),
                )
                sent += 1
                print(json.dumps(tick), flush=True)
                if args.count and sent >= args.count:
                    break
            if args.count == 0 or sent < args.count:
                time.sleep(args.interval)
    except KeyboardInterrupt:
        pass


if __name__ == "__main__":
    main()
