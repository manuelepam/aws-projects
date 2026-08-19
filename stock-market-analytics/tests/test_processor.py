import base64
import json
import os

os.environ.setdefault("RAW_BUCKET", "unit-test-raw-bucket")
os.environ.setdefault("DYNAMODB_TABLE", "unit-test-cleaned-table")
os.environ.setdefault("SNS_TOPIC_ARN", "arn:aws:sns:eu-north-1:123456789012:unit-test")

import lambda_function as processor


def raw_event(percent_change=1.5):
    return {
        "symbol": "aapl",
        "provider": "finnhub",
        "ingested_at": "2026-08-14T13:30:00+00:00",
        "quote": {
            "c": 203.5,
            "d": 3.0,
            "dp": percent_change,
            "h": 204.0,
            "l": 199.0,
            "o": 200.0,
            "pc": 200.5,
            "t": 1786714200,
        },
    }


def kinesis_record(payload, sequence_number="123"):
    return {
        "kinesis": {
            "data": base64.b64encode(json.dumps(payload).encode()).decode(),
            "sequenceNumber": sequence_number,
        }
    }


def test_clean_stock_event_normalizes_and_detects_anomaly():
    cleaned = processor.clean_stock_event(raw_event(percent_change=3.2))

    assert cleaned["symbol"] == "AAPL"
    assert cleaned["current_price"] == 203.5
    assert cleaned["is_anomaly"] is True
    assert cleaned["anomaly_reason"] == "Price moved 3.20% from the previous close"


def test_lambda_handler_archives_stores_and_alerts(monkeypatch):
    archived = []
    stored = []
    alerted = []
    monkeypatch.setattr(
        processor,
        "archive_raw_event",
        lambda event, sequence: archived.append((event["symbol"], sequence)) or "raw/test.json",
    )
    monkeypatch.setattr(processor, "store_cleaned_event", lambda event: stored.append(event))
    monkeypatch.setattr(processor, "publish_anomaly_alert", lambda event: alerted.append(event))

    result = processor.lambda_handler(
        {"Records": [kinesis_record(raw_event(percent_change=4.0))]},
        None,
    )

    assert result == {"statusCode": 200, "processedRecords": 1}
    assert archived == [("aapl", "123")]
    assert stored[0]["symbol"] == "AAPL"
    assert alerted[0]["is_anomaly"] is True
