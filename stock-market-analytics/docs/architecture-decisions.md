# Architecture decisions

## Kinesis rather than SQS

Ticks are an ordered, replayable stream partitioned by symbol. SQS is an excellent work queue but does not naturally provide multiple independent consumers or time-based replay.

## DynamoDB and S3 serve different access patterns

DynamoDB answers “what is the latest price for this symbol?” with a key lookup. S3 and Athena answer historical, aggregate questions economically. Forcing both workloads into one database would weaken one of them.

## Direct S3 writes in the learning version

The Lambda writes one object per tick to make the entire flow visible and easy to inspect. That creates many small files. A production pipeline should buffer and convert records to Parquet with Firehose or a compaction job.

## Partition projection rather than a Glue crawler

The object-key schema is deterministic. Projection makes new hourly partitions available without running and paying for a crawler, while the Glue Catalog still provides the table definition Athena needs.

## At-least-once delivery

Kinesis and Lambda can retry records. The raw object key includes the immutable sequence number, so replay overwrites the same object. The latest-price write is naturally repeatable, though a production design should guard against an older retried event replacing newer state.

