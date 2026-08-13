import base64
import json
from decimal import Decimal

import processor


def record(payload):
    return {
        "kinesis": {
            "data": base64.b64encode(json.dumps(payload).encode()).decode(),
            "sequenceNumber": "123",
        }
    }


def test_decode_record_normalizes_types():
    tick = processor.decode_record(
        record({"symbol": "aapl", "price": 201.5, "volume": 42, "timestamp": "2026-01-02T03:04:05Z"})
    )
    assert tick["symbol"] == "AAPL"
    assert tick["price"] == Decimal("201.5")


def test_handler_reports_only_failed_items(monkeypatch):
    archived = []
    monkeypatch.setattr(processor, "archive_tick", lambda tick, seq: archived.append(seq))
    monkeypatch.setattr(processor, "update_latest_and_alert", lambda tick: None)
    event = {
        "Records": [
            record({"symbol": "MSFT", "price": 10, "volume": 1, "timestamp": "2026-01-01T00:00:00Z"}),
            record({"symbol": "BROKEN"}),
        ]
    }
    event["Records"][1]["kinesis"]["sequenceNumber"] = "456"
    assert processor.handler(event, None) == {"batchItemFailures": [{"itemIdentifier": "456"}]}
    assert archived == ["123"]
