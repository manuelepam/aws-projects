import base64
import json

from src.detector import is_brute_force


def decode_kinesis_record(record: dict) -> dict:
    encoded_data = record["kinesis"]["data"]
    decoded_bytes = base64.b64decode(encoded_data)
    decoded_text = decoded_bytes.decode("utf-8")
    return json.loads(decoded_text)


def lambda_handler(event: dict, context: object) -> dict:
    records = event["Records"]
    findings = []

    for record in records:
        decoded_event = decode_kinesis_record(record)
        if is_brute_force(decoded_event):
            findings.append(decoded_event)

    return {
        "records_processed": len(records),
        "findings_created": len(findings),
        "findings": findings,
    }
