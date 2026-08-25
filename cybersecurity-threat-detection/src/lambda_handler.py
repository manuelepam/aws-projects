import base64
import binascii
import json

from src.detector import is_brute_force


def decode_kinesis_record(record: dict) -> dict:
    encoded_data = record["kinesis"]["data"]
    decoded_bytes = base64.b64decode(encoded_data, validate=True)
    decoded_text = decoded_bytes.decode("utf-8")
    return json.loads(decoded_text)


def lambda_handler(event: dict, context: object) -> dict:
    records = event["Records"]
    findings = []
    failed_records = 0
    batch_item_failures = []

    for record in records:
        try:
            decoded_event = decode_kinesis_record(record)

            if is_brute_force(decoded_event):
                findings.append(decoded_event)
        except (
            binascii.Error,
            UnicodeDecodeError,
            json.JSONDecodeError,
            KeyError,
            TypeError,
        ):
            failed_records += 1
            sequence_number = record["kinesis"]["sequenceNumber"]
            batch_item_failures.append(
                {"itemIdentifier": sequence_number}
            )

    return {
        "records_processed": len(records),
        "records_failed": failed_records,
        "findings_created": len(findings),
        "findings": findings,
        "batchItemFailures": batch_item_failures,
    }
