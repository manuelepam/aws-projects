import base64
import binascii
import json
import logging
import os

from src.detector import is_brute_force

logger = logging.getLogger()
logger.setLevel(logging.INFO)
alert_topic_arn = os.environ.get("ALERT_TOPIC_ARN")
sns_client = None


def decode_kinesis_record(record: dict) -> dict:
    encoded_data = record["kinesis"]["data"]
    decoded_bytes = base64.b64decode(encoded_data, validate=True)
    decoded_text = decoded_bytes.decode("utf-8")
    return json.loads(decoded_text)


def publish_security_alert(finding: dict) -> None:
    if not alert_topic_arn:
        return

    global sns_client

    if sns_client is None:
        import boto3

        sns_client = boto3.client("sns")

    sns_client.publish(
        TopicArn=alert_topic_arn,
        Subject="Brute-force activity detected",
        Message=json.dumps(
            {
                "finding_type": "BRUTE_FORCE",
                "finding": finding,
            },
            indent=2,
        ),
    )


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
                logger.warning(
                    json.dumps(
                        {
                            "message": "brute_force_detected",
                            "finding": decoded_event,
                        }
                    )
                )
                publish_security_alert(decoded_event)
        except (
            binascii.Error,
            UnicodeDecodeError,
            json.JSONDecodeError,
            KeyError,
            TypeError,
        ) as error:
            failed_records += 1
            sequence_number = record["kinesis"]["sequenceNumber"]
            batch_item_failures.append(
                {"itemIdentifier": sequence_number}
            )
            logger.error(
                json.dumps(
                    {
                        "message": "record_processing_failed",
                        "sequence_number": sequence_number,
                        "error_type": type(error).__name__,
                    }
                )
            )
    logger.info(
        json.dumps(
            {
                "message": "batch_processed",
                "records_processed": len(records),
                "records_failed": failed_records,
                "findings_created": len(findings),
            }
        )
    )

    return {
        "records_processed": len(records),
        "records_failed": failed_records,
        "findings_created": len(findings),
        "findings": findings,
        "batchItemFailures": batch_item_failures,
    }
