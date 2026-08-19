# Stock Market Analytics on AWS

A serverless stock-data pipeline managed with Terraform. EventBridge Scheduler invokes a Finnhub producer during US market hours, Kinesis streams each quote to a processor, and the processor archives raw data, stores cleaned records, and publishes anomaly alerts.

## Architecture

```mermaid
flowchart LR
    EB["EventBridge Scheduler"] --> P["Producer Lambda"]
    SM["Secrets Manager<br/>Finnhub API key"] --> P
    P --> K["Kinesis Data Stream"]
    K --> C["Processor Lambda"]
    C --> S3["S3 raw archive"]
    C --> DDB["DynamoDB cleaned records"]
    C --> SNS["SNS anomaly alerts"]
    S3 --> G["Glue Data Catalog"]
    G --> A["Athena"]
```

The schedules use `America/New_York`, so EventBridge Scheduler handles daylight-saving changes:

- `cron(30/5 9 ? * MON-FRI *)`: every five minutes from 09:30 through 09:55.
- `cron(0/5 10-15 ? * MON-FRI *)`: every five minutes from 10:00 through 15:55.

These expressions handle weekdays, but not US market holidays or early-closing days.

## Infrastructure as Code

Terraform in [`infra`](infra) manages the existing live resources in account `436856560914`, region `eu-north-1`. The original console-created resources were adopted using declarative import blocks in [`infra/imports.tf`](infra/imports.tf).

The Finnhub secret container is managed, but its secret value is deliberately excluded from Terraform so the API key is not written into Terraform state.

The Lambda deployment source is stored under [`lambda`](lambda). Terraform packages these files and uses their source hashes to deploy code changes. The processor tests import the same module that Terraform packages, so the tested implementation and deployed implementation cannot silently diverge.

## Safe workflow

Always review a plan before applying:

```bash
terraform -chdir=infra fmt -check -recursive
terraform -chdir=infra validate
terraform -chdir=infra plan -out=change.tfplan
terraform -chdir=infra apply change.tfplan
```

After the initial import, a clean configuration should report:

```text
No changes. Your infrastructure matches the configuration.
```

Never commit `.tfstate`, `.tfplan`, generated ZIP files, `.env` files, or AWS credentials. The repository `.gitignore` excludes these local artifacts.

## Managed resources

- Kinesis stream `stock-market-stream`
- Lambdas `stock-data-producer` and `stock-data-processor`
- DynamoDB table `stock-market-cleaned`
- S3 bucket `stock-market-raw-data-8f3c2a`
- SNS topic and confirmed email subscription
- Secrets Manager secret metadata
- IAM roles, inline policies, managed policies, and attachments
- Kinesis-to-Lambda event source mapping
- Glue database and external raw-data table
- Two EventBridge Scheduler schedules
- Disabled legacy five-minute EventBridge rule
- Lambda CloudWatch log groups
- Four CloudWatch operational alarms and an operations dashboard
- Separate SNS email notifications for infrastructure failures
- Athena workgroup with four saved analytical queries and a per-query scan limit

## Operational monitoring

The `stock-market-operations` CloudWatch dashboard shows Lambda invocations,
errors and duration, Kinesis throughput and consumer lag, Scheduler delivery,
and DynamoDB activity. Four alarms notify the separate
`stock-market-operations` SNS topic when either Lambda fails, the Kinesis
consumer is more than five minutes behind, or Scheduler cannot invoke its
target. Missing metrics are treated as healthy while the schedules and event
source mapping are deliberately disabled.

## Pipeline switch

The `pipeline_enabled` variable controls the two market-hours schedules and
the Kinesis-to-processor event source mapping together. It defaults to
`false`, keeping automatic ingestion disabled unless it is deliberately
enabled for a test:

```bash
terraform -chdir=infra plan -var='pipeline_enabled=true' -out=enable.tfplan
terraform -chdir=infra apply enable.tfplan
```

Return to the safe default after testing:

```bash
terraform -chdir=infra plan -out=disable.tfplan
terraform -chdir=infra apply disable.tfplan
```

The legacy EventBridge rule is intentionally excluded from this switch and
remains disabled.

## Historical analytics

Athena queries the JSON archive through the projected Glue table, so no crawler
is required. The `stock-market-analytics` workgroup forces encrypted results to
the existing raw-data bucket under `athena-results/`, limits each query to 100
MB scanned, publishes workgroup metrics to CloudWatch, and expires result files
after seven days.

Terraform creates four saved queries scoped to the current day's projected
partitions, avoiding a scan of every possible partition in the projection
range:

- Latest stock price by symbol
- Average, minimum and maximum price by symbol
- Largest percentage movements
- Records processed per hour

In the Athena console, select the `stock-market-analytics` workgroup and the
`stock_market_analytics` database before running a saved query. Athena charges
by data scanned, so use partition filters for larger datasets even with the
workgroup cutoff.

## Verified outcome

The pipeline was validated end to end by invoking the producer, observing the
record pass through Kinesis and the processor, confirming S3 and DynamoDB
activity on the CloudWatch dashboard, and querying the archive with Athena.
The partition-filtered latest-price query returned AAPL, AMZN and MSFT in 482
ms while scanning 1.24 KB. The same unfiltered query took 2 minutes 25 seconds,
demonstrating why partition pruning matters even for a small dataset.

The pre-teardown screenshot checklist and portfolio evidence are documented in
[`docs/project-evidence.md`](docs/project-evidence.md).

## Security note

The local `terraform-admin` access key has broad permissions for this personal sandbox. Rotate or deactivate it when it is no longer needed. For production, prefer short-lived IAM Identity Center credentials, remote encrypted Terraform state with locking, narrowly scoped roles, deletion protection, and CI/CD-based plans and applies.

## Controlled teardown

The raw-data bucket is protected from deletion while it contains objects. The
`allow_data_deletion` variable defaults to `false`; it must be set explicitly
before a complete teardown. This makes destructive intent visible in both the
Terraform plan and command history.

```bash
terraform -chdir=infra plan -var='allow_data_deletion=true' -out=allow-destroy.tfplan
terraform -chdir=infra apply allow-destroy.tfplan
terraform -chdir=infra plan -destroy -var='allow_data_deletion=true' -out=destroy.tfplan
terraform -chdir=infra apply destroy.tfplan
```

The final apply permanently deletes the S3 archive, DynamoDB records and the
remaining project infrastructure. Back up any data that must be retained
before running it.
