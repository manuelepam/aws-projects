import json
import os
import urllib.parse
import urllib.request
from datetime import datetime, timezone

import boto3


STREAM_NAME = os.environ["STREAM_NAME"]
SECRET_ID = os.environ["SECRET_ID"]
SYMBOLS = [symbol.strip() for symbol in os.environ["SYMBOLS"].split(",") if symbol.strip()]

kinesis = boto3.client("kinesis")
secrets_manager = boto3.client("secretsmanager")
_cached_api_key = None


def get_api_key():
    global _cached_api_key
    if _cached_api_key is None:
        response = secrets_manager.get_secret_value(SecretId=SECRET_ID)
        secret = json.loads(response["SecretString"])
        _cached_api_key = secret["FINNHUB_API_KEY"].strip()
    return _cached_api_key


def fetch_quote(symbol, api_key):
    query = urllib.parse.urlencode({"symbol": symbol, "token": api_key})
    request = urllib.request.Request(
        f"https://finnhub.io/api/v1/quote?{query}",
        headers={"User-Agent": "stock-data-producer/1.0"},
    )
    with urllib.request.urlopen(request, timeout=5) as response:
        quote = json.loads(response.read().decode("utf-8"))
    if "error" in quote:
        raise ValueError(f"Finnhub error for {symbol}: {quote['error']}")
    if float(quote.get("c", 0)) <= 0:
        raise ValueError(f"Invalid quote returned for {symbol}")
    return quote


def lambda_handler(event, context):
    api_key = get_api_key()
    sent = []
    failed = []
    for symbol in SYMBOLS:
        try:
            quote = fetch_quote(symbol, api_key)
            stock_event = {
                "symbol": symbol,
                "provider": "finnhub",
                "ingested_at": datetime.now(timezone.utc).isoformat(),
                "quote": quote,
            }
            response = kinesis.put_record(
                StreamName=STREAM_NAME,
                PartitionKey=symbol,
                Data=json.dumps(stock_event).encode("utf-8"),
            )
            sent.append(symbol)
            print(json.dumps({"message": "Stock event sent", "symbol": symbol, "sequence_number": response["SequenceNumber"]}))
        except Exception as error:
            failed.append({"symbol": symbol, "error": str(error)})
            print(json.dumps({"message": "Failed to send stock event", "symbol": symbol, "error": str(error)}))
    return {"statusCode": 200 if not failed else 207, "body": json.dumps({"sent": sent, "failed": failed})}
