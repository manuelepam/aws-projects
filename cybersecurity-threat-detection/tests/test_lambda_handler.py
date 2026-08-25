import base64
import json

from src.lambda_handler import decode_kinesis_record, lambda_handler


def make_kinesis_record(event: dict, sequence_number: str = "1") -> dict:
    json_text = json.dumps(event)
    event_bytes = json_text.encode("utf-8")
    encoded_data = base64.b64encode(event_bytes).decode("utf-8")

    return {
        "kinesis": {
            "data": encoded_data,
            "sequenceNumber": sequence_number,
        }
    }

def test_decode_kinesis_record() -> None:
    original_event = {
        "event_type": "LOGIN",
        "authentication_result": "FAILURE",
        "failed_attempts_last_5m": 25,
    }
    record = make_kinesis_record(original_event)

    assert decode_kinesis_record(record) == original_event

def test_lambda_handler_processes_mixed_batch() -> None:
    normal_event = {
        "event_type": "LOGIN",
        "authentication_result": "SUCCESS",
        "failed_attempts_last_5m": 0,
    }

    suspicious_event = {
        "event_type": "LOGIN",
        "authentication_result": "FAILURE",
        "failed_attempts_last_5m": 25,
    }

    lambda_event = {
        "Records": [
            make_kinesis_record(normal_event),
            make_kinesis_record(suspicious_event),
        ]
    }

    result = lambda_handler(lambda_event, None)

    assert result["records_processed"] == 2
    assert result["records_failed"] == 0
    assert result["batchItemFailures"] == []
    assert result["findings_created"] == 1
    assert result["findings"] == [suspicious_event]

def test_lambda_handler_continues_after_malformed_record() -> None:
    suspicious_event = {
        "event_type": "LOGIN",
        "authentication_result": "FAILURE",
        "failed_attempts_last_5m": 25,
    }

    malformed_record = {
        "kinesis": {
            "data": "not-valid-base64!",
            "sequenceNumber": "100",
        }
    }

    lambda_event = {
        "Records": [
            malformed_record,
            make_kinesis_record(suspicious_event, "101"),
        ]
    }

    result = lambda_handler(lambda_event, None)

    assert result["records_processed"] == 2
    assert result["records_failed"] == 1
    assert result["findings_created"] == 1
    assert result["findings"] == [suspicious_event]
    assert result["batchItemFailures"] == [
        {"itemIdentifier": "100"}
    ]
