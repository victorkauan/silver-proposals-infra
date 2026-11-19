# Monitoring

Every alarm notifies the SNS topic `silver-proposals-alerts`, which e-mails the addresses in the
`BUDGET_ALERT_EMAILS` secret (each address confirms its subscription once). Alarms send a message when they fire and
another when they recover.

## Dashboards

One CloudWatch dashboard per environment, `silver-proposals-staging` and `silver-proposals-prod`: API requests and
errors, latency (p50/p95), healthy targets, ECS CPU and memory, proposal generations (count, failures, Bedrock
latency), the shared database, recent errors from the logs, and the state of every alarm.

## Alarms

| Alarm | Fires when | First thing to check |
|---|---|---|
| `silver-proposals-<env>-api-down` | no healthy API target for 3 minutes (also when the service runs no task) | ECS service events and the `api` log stream; `/ready` fails if the database is unreachable |
| `silver-proposals-<env>-api-5xx` | 5 or more 5xx responses from the API in 5 minutes | the dashboard's "Recent API errors" and the `request_id` of a failing request |
| `silver-proposals-<env>-api-latency` | p95 time to first byte above 2 s for 15 minutes | database CPU and connections; X-Ray traces of slow requests |
| `silver-proposals-<env>-api-cpu` / `-api-memory` | CPU above 80% / memory above 85% for 15 minutes | traffic on the dashboard; raise `cpu` or `memory` of the task if it is steady |
| `silver-proposals-<env>-generation-failures` | 3 or more failed generations in 15 minutes | `generation_failed` log lines (`error_code`): Bedrock throttling, timeouts, or access |
| `silver-proposals-<env>-api-errors` | 5 or more `ERROR` log lines in 5 minutes | the dashboard's "Recent API errors" |
| `silver-proposals-<env>-app-5xx` | more than 5% of the app's CloudFront requests fail for 15 minutes | the S3 bucket and the latest frontend deploy |
| `silver-proposals-db-cpu` / `-db-memory` | database CPU above 80% / freeable memory below 32 MiB for 15 minutes (it normally keeps 50 to 60 MiB free) | slow queries in the database log group; consider a larger instance class |
| `silver-proposals-db-storage` | free storage below 2 GiB | storage autoscaling (up to 50 GiB) should act first |
| `silver-proposals-db-connections` | more than 60 connections | connection leaks; both environments share the instance |
| `silver-proposals-alb-5xx` | 5 or more 5xx responses from the load balancer itself in 5 minutes | `api-down` in either environment |

The application metrics (`SilverProposals/<env>`: `GenerationsCompleted`, `GenerationsFailed`, `GenerationLatency`,
`Errors`) come from metric filters on the API's JSON logs, so the API needs no metrics SDK.

## Traces

Each API task runs the AWS Distro for OpenTelemetry collector as a sidecar. The API sends OTLP traces to it on
`127.0.0.1:4318`, and it forwards them to AWS X-Ray (service `silver-proposals-api-<env>`). Requests, database
queries, and Bedrock calls appear as spans; log lines carry the matching `trace_id`.

## Pausing

To pause the project without a flood of alarms, use `scripts/environment-power.sh`; see
[Pause and resume the project](../runbooks/pause-and-resume.md).

## Test an alarm

```bash
aws cloudwatch set-alarm-state --alarm-name silver-proposals-staging-api-errors \
  --state-value ALARM --state-reason "Manual test of the alert path"
```

The alarm returns to `OK` at its next evaluation, which sends the recovery e-mail.
