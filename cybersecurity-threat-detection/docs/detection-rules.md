# Detection Rules

## Rule 1: Possible Brute-Force Login

**Severity:** High

Trigger when all of these conditions are true:

- `event_type` equals `LOGIN`.
- `authentication_result` equals `FAILURE`.
- `failed_attempts_last_5m` is greater than or equal to `10`.

### Rationale

Repeated login failures from one source in a short period may indicate automated password guessing.

### Possible False Positives

- A legitimate user repeatedly mistypes a password.
- An authorised security test intentionally generates failed logins.

### Response

- Create a high-severity security finding.
- Send an alert through Amazon SNS.
- Store the original event for investigation.
- Do not automatically block the source in the first version.
