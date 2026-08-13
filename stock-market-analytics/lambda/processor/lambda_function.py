import base64
import json
import os
from datetime import datetime, timezone
from decimal import Decimal

import boto3


ANOMALY_THRESHOLD_PERCENT = 3.0
s3 = boto3.client("s3")
dynamodb = boto3.resource("dynamodb")
sns = boto3.client("sns")
raw_bucket = os.environ["RAW_BUCKET"]
cleaned_table = dynamodb.Table(os.environ["DYNAMODB_TABLE"])
SNS_TOPIC_ARN = os.environ["SNS_TOPIC_ARN"]


def archive_raw_event(raw_event, sequence_number):
    ingested_time = datetime.fromisoformat(raw_event["ingested_at"].replace("Z", "+00:00"))
    symbol = raw_event["symbol"].upper()
    object_key = (
        f"raw/year={ingested_time:%Y}/month={ingested_time:%m}/"
        f"day={ingested_time:%d}/hour={ingested_time:%H}/"
        f"{symbol}-{sequence_number}.json"
    )
    s3.put_object(
        Bucket=raw_bucket,
        Key=object_key,
        Body=json.dumps(raw_event).encode("utf-8"),
        ContentType="application/json",
        ServerSideEncryption="AES256",
    )
    return object_key


def clean_stock_event(raw_event):
    symbol = raw_event["symbol"].upper()
    quote = raw_event["quote"]
    for field in ["c", "h", "l", "o", "pc", "t"]:
        if field not in quote:
            raise ValueError(f"Missing Finnhub field: {field}")
    current_price = float(quote["c"])
    if current_price <= 0:
        raise ValueError(f"Invalid price for {symbol}: {current_price}")
    percent_change = float(quote.get("dp", 0))
    is_anomaly = abs(percent_change) >= ANOMALY_THRESHOLD_PERCENT
    cleaned_event = {
        "symbol": symbol,
        "ingested_at": raw_event["ingested_at"],
        "current_price": current_price,
        "open_price": float(quote["o"]),
        "high_price": float(quote["h"]),
        "low_price": float(quote["l"]),
        "previous_close": float(quote["pc"]),
        "price_change": float(quote.get("d", 0)),
        "percent_change": percent_change,
        "market_timestamp": datetime.fromtimestamp(int(quote["t"]), tz=timezone.utc).isoformat(),
        "provider": raw_event.get("provider", "unknown"),
        "is_anomaly": is_anomaly,
    }
    if is_anomaly:
        cleaned_event["anomaly_reason"] = f"Price moved {percent_change:.2f}% from the previous close"
    return cleaned_event


def publish_anomaly_alert(cleaned_event):
    sns.publish(
        TopicArn=SNS_TOPIC_ARN,
        Subject=f"Stock anomaly: {cleaned_event['symbol']}",
        Message=(
            "An unusual stock movement was detected.\n\n"
            f"Symbol: {cleaned_event['symbol']}\n"
            f"Current price: {cleaned_event['current_price']}\n"
            f"Percentage change: {cleaned_event['percent_change']:.2f}%\n"
            f"Reason: {cleaned_event.get('anomaly_reason', 'Threshold exceeded')}\n"
            f"Ingested at: {cleaned_event['ingested_at']}"
        ),
    )


def store_cleaned_event(cleaned_event):
    cleaned_table.put_item(Item=json.loads(json.dumps(cleaned_event), parse_float=Decimal))


def lambda_handler(event, context):
    processed_records = []
    for record in event.get("Records", []):
        raw_event = json.loads(base64.b64decode(record["kinesis"]["data"]).decode("utf-8"))
        sequence_number = record["kinesis"]["sequenceNumber"]
        s3_object_key = archive_raw_event(raw_event, sequence_number)
        cleaned_event = clean_stock_event(raw_event)
        store_cleaned_event(cleaned_event)
        processed_records.append(cleaned_event)
        if cleaned_event["is_anomaly"]:
            publish_anomaly_alert(cleaned_event)
        print(json.dumps({"message": "Stock event stored", "s3_object_key": s3_object_key, "record": cleaned_event}))
    return {"statusCode": 200, "processedRecords": len(processed_records)}
