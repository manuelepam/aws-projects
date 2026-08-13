"""Kinesis consumer: archive ticks, update latest prices, and publish price alerts."""

from __future__ import annotations

import base64
import json
import os
from datetime import datetime
from decimal import Decimal
from typing import Any

import boto3

s3 = boto3.client("s3")
dynamodb = boto3.resource("dynamodb")
sns = boto3.client("sns")


def _decimal(value: Any) -> Decimal:
    return Decimal(str(value))


def decode_record(record: dict[str, Any]) -> dict[str, Any]:
    payload = base64.b64decode(record["kinesis"]["data"])
    tick = json.loads(payload)
    required = {"symbol", "price", "volume", "timestamp"}
    missing = required - tick.keys()
    if missing:
        raise ValueError(f"Missing fields: {', '.join(sorted(missing))}")
    tick["symbol"] = str(tick["symbol"]).upper()
    tick["price"] = _decimal(tick["price"])
    tick["volume"] = int(tick["volume"])
    return tick


def archive_tick(tick: dict[str, Any], sequence_number: str) -> None:
    observed = datetime.fromisoformat(str(tick["timestamp"]))
    key = (
        f"ticks/year={observed:%Y}/month={observed:%m}/day={observed:%d}/"
        f"hour={observed:%H}/{tick['symbol']}-{sequence_number}.json"
    )
    body = json.dumps(tick, default=str, separators=(",", ":")) + "\n"
    s3.put_object(
        Bucket=os.environ["RAW_BUCKET"],
        Key=key,
        Body=body.encode(),
        ContentType="application/x-ndjson",
        ServerSideEncryption="AES256",
    )


def update_latest_and_alert(tick: dict[str, Any]) -> None:
    table = dynamodb.Table(os.environ["LATEST_PRICES_TABLE"])
    previous = table.get_item(Key={"symbol": tick["symbol"]}, ConsistentRead=True).get("Item")
    table.put_item(Item=tick)

    if not previous:
        return
    previous_price = _decimal(previous["price"])
    if previous_price == 0:
        return
    change = (tick["price"] - previous_price) / previous_price * 100
    threshold = _decimal(os.environ.get("ALERT_THRESHOLD_PERCENT", "5"))
    if abs(change) >= threshold:
        sns.publish(
            TopicArn=os.environ["ALERT_TOPIC_ARN"],
            Subject=f"Stock price alert: {tick['symbol']}",
            Message=(
                f"{tick['symbol']} moved {change:.2f}% from {previous_price} "
                f"to {tick['price']} at {tick['timestamp']}."
            ),
        )


def handler(event: dict[str, Any], _context: Any) -> dict[str, Any]:
    failures = []
    for record in event.get("Records", []):
        sequence = record["kinesis"]["sequenceNumber"]
        try:
            tick = decode_record(record)
            archive_tick(tick, sequence)
            update_latest_and_alert(tick)
        except Exception:  # noqa: BLE001 - report the precise failed Kinesis item.
            failures.append({"itemIdentifier": sequence})
    return {"batchItemFailures": failures}
