---
status: accepted
date: 2026-11-18
decision-makers: Victor Kauan
---

# Share the load balancer and the database between staging and production

## Context and Problem Statement

The project runs two environments, staging and production, in one AWS account with a monthly budget alert of
USD 40. On-demand prices in us-east-1 (AWS Price List API, 2026-11-18) put one environment with its own
Application Load Balancer, RDS instance, and Fargate task at about USD 53 per month, so two fully separate
environments cost about USD 106 per month. How do we keep two real environments while keeping the cost close to
the budget?

| Item (one environment, 730 h/month) | Monthly cost |
|---|---|
| Application Load Balancer (USD 0.0225/h plus a few LCUs) | about USD 17 to 19 |
| Two public IPv4 addresses of the ALB (USD 0.005/h each) | USD 7.30 |
| RDS PostgreSQL db.t4g.micro Single-AZ (USD 0.016/h) and 20 GB gp3 (USD 0.115/GB-month) | USD 13.98 |
| Fargate 0.25 vCPU / 0.5 GB (USD 0.04048 per vCPU-hour, USD 0.00445 per GB-hour) and its public IPv4 | USD 12.66 |
| Secrets Manager, CloudFront, S3, ECR, logs | about USD 2 |

## Decision Drivers

- Stay near the USD 40/month alert (AWS credits cover the actual spend).
- Keep two environments with separate deploys, data, secrets, and URLs.
- Keep the isolation trade-offs explicit for the report.

## Considered Options

- Fully separate stacks per environment (about USD 106/month)
- Separate stacks, with staging created only while testing (about USD 53/month plus staging hours)
- Shared load balancer and database instance, everything else per environment (about USD 66/month)

## Decision Outcome

Chosen option: **share the load balancer and the database instance**. A `shared` root module owns the network,
the ALB, the RDS instance, the ECR repository, and the budget. Each environment root module owns everything else:

| Shared (`environments/shared`) | Per environment (`environments/staging`, `environments/prod`) |
|---|---|
| VPC, public and isolated subnets, S3 gateway endpoint | ECS cluster, service, and task definition |
| ALB with HTTPS listener (certificate for `api` and `api-staging`) | Host-based listener rule and target group |
| RDS PostgreSQL instance (master password managed by RDS) | Own database and login role on the instance |
| ECR repository (an image is built once and promoted) | Secrets Manager secret (JWT secret, database URL) |
| AWS Budget | Task and execution IAM roles, security group, log group |
| | S3 bucket, CloudFront distribution, certificate for `app` |
| | Cloudflare records `app[-staging]` and `api[-staging]` |

Isolation between the environments still holds where it matters:

- **Data:** each environment has its own database and role, created by a one-off task with the RDS master
  credentials. `CONNECT` is revoked from `PUBLIC`, so the staging role cannot open the production database.
- **Network:** each environment's tasks have their own security group; the database accepts each one explicitly.
- **Secrets and IAM:** separate secrets, task roles, and execution roles; no role can read the other's secret.
- **State and CI:** separate state keys; each CI role writes only its own state and reads the shared one.

### Consequences

- Good: about 38% cheaper than separate stacks, with the same deploy flow per environment.
- Good: one image repository supports "build once, promote to production".
- Bad: the ALB and the database are a shared failure domain; a bad change in `shared` affects both environments.
  Changes to `shared` therefore require the same approval as production.
- Bad: staging load can affect production performance on the shared database. Acceptable at this scale.

## More Information

- AWS Price List API, us-east-1, queried on 2026-11-18.
- [ADR-0002](0002-terraform-state-in-s3-with-native-locking.md) for the state layout.
