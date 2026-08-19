resource "aws_s3_bucket_lifecycle_configuration" "athena_results" {
  bucket = aws_s3_bucket.raw.id

  rule {
    id     = "expire-athena-query-results"
    status = "Enabled"

    filter {
      prefix = "athena-results/"
    }

    expiration {
      days = 7
    }
  }
}

resource "aws_athena_workgroup" "analytics" {
  name          = "stock-market-analytics"
  description   = "Cost-controlled SQL analysis of archived stock quotes"
  state         = "ENABLED"
  force_destroy = true

  configuration {
    enforce_workgroup_configuration    = true
    publish_cloudwatch_metrics_enabled = true
    bytes_scanned_cutoff_per_query     = 104857600

    result_configuration {
      output_location       = "s3://${aws_s3_bucket.raw.id}/athena-results/"
      expected_bucket_owner = local.account_id

      encryption_configuration {
        encryption_option = "SSE_S3"
      }
    }
  }
}

resource "aws_athena_named_query" "latest_prices" {
  name        = "Latest stock price by symbol"
  description = "Returns today's newest archived quote for each stock symbol."
  database    = aws_glue_catalog_database.analytics.name
  workgroup   = aws_athena_workgroup.analytics.name
  query = trimspace(<<-SQL
    WITH ranked_quotes AS (
      SELECT
        symbol,
        quote.c AS current_price,
        quote.dp AS percent_change,
        ingested_at,
        row_number() OVER (
          PARTITION BY symbol
          ORDER BY from_iso8601_timestamp(ingested_at) DESC
        ) AS row_number
      FROM ${aws_glue_catalog_database.analytics.name}.${aws_glue_catalog_table.raw.name}
      WHERE year = date_format(CAST(current_date AS timestamp), '%Y')
        AND month = date_format(CAST(current_date AS timestamp), '%m')
        AND day = date_format(CAST(current_date AS timestamp), '%d')
    )
    SELECT symbol, current_price, percent_change, ingested_at
    FROM ranked_quotes
    WHERE row_number = 1
    ORDER BY symbol;
  SQL
  )
}

resource "aws_athena_named_query" "average_price" {
  name        = "Average stock price by symbol"
  description = "Calculates today's average, minimum and maximum archived prices per symbol."
  database    = aws_glue_catalog_database.analytics.name
  workgroup   = aws_athena_workgroup.analytics.name
  query = trimspace(<<-SQL
    SELECT
      symbol,
      count(*) AS quote_count,
      round(avg(quote.c), 2) AS average_price,
      min(quote.c) AS minimum_price,
      max(quote.c) AS maximum_price
    FROM ${aws_glue_catalog_database.analytics.name}.${aws_glue_catalog_table.raw.name}
    WHERE year = date_format(CAST(current_date AS timestamp), '%Y')
      AND month = date_format(CAST(current_date AS timestamp), '%m')
      AND day = date_format(CAST(current_date AS timestamp), '%d')
    GROUP BY symbol
    ORDER BY symbol;
  SQL
  )
}

resource "aws_athena_named_query" "largest_movements" {
  name        = "Largest percentage movements"
  description = "Lists today's quotes with the largest absolute percentage changes."
  database    = aws_glue_catalog_database.analytics.name
  workgroup   = aws_athena_workgroup.analytics.name
  query = trimspace(<<-SQL
    SELECT
      symbol,
      quote.c AS current_price,
      quote.dp AS percent_change,
      ingested_at
    FROM ${aws_glue_catalog_database.analytics.name}.${aws_glue_catalog_table.raw.name}
    WHERE year = date_format(CAST(current_date AS timestamp), '%Y')
      AND month = date_format(CAST(current_date AS timestamp), '%m')
      AND day = date_format(CAST(current_date AS timestamp), '%d')
      AND quote.dp IS NOT NULL
    ORDER BY abs(quote.dp) DESC
    LIMIT 20;
  SQL
  )
}

resource "aws_athena_named_query" "records_per_hour" {
  name        = "Records processed per hour"
  description = "Counts today's archived stock quotes by ingestion hour."
  database    = aws_glue_catalog_database.analytics.name
  workgroup   = aws_athena_workgroup.analytics.name
  query = trimspace(<<-SQL
    SELECT
      date_trunc('hour', from_iso8601_timestamp(ingested_at)) AS ingestion_hour,
      count(*) AS record_count
    FROM ${aws_glue_catalog_database.analytics.name}.${aws_glue_catalog_table.raw.name}
    WHERE year = date_format(CAST(current_date AS timestamp), '%Y')
      AND month = date_format(CAST(current_date AS timestamp), '%m')
      AND day = date_format(CAST(current_date AS timestamp), '%d')
    GROUP BY 1
    ORDER BY ingestion_hour DESC;
  SQL
  )
}
