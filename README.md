# Silver Proposals — Infrastructure

Infrastructure as code for **Silver Proposals**, an AI-powered SaaS for creating and managing commercial proposals.
This repo defines the AWS resources (us-east-2) and Cloudflare DNS records that the application runs on,
the infrastructure CI/CD, and the system-level documentation.

| Repository | Responsibility |
|---|---|
| [silver-proposals-backend](https://github.com/victorkauan/silver-proposals-backend) | FastAPI API, container image published to ECR |
| [silver-proposals-frontend](https://github.com/victorkauan/silver-proposals-frontend) | React SPA, static build published to S3 + CloudFront |
| **silver-proposals-infra** (this repo) | Terraform for AWS and Cloudflare, outputs consumed by the other two repos |

Why three repositories: [ADR-0001](docs/adr/0001-three-repositories.md).
How the outputs reach the app pipelines: [outputs contract](docs/reference/outputs-contract.md).

## Layout

```
bootstrap/        # one-time root module: the S3 bucket that stores every Terraform state
environments/
  shared/         # network, load balancer, database, image registry, budget (used by both environments)
  staging/        # root module for staging (app-staging / api-staging.silversoft.com.br)
  prod/           # root module for production (app / api.silversoft.com.br)
modules/          # network, alb, database, ecr, budget, acm_certificate, frontend, api_service, app_environment
docs/             # architecture, ADRs, guides, reference, runbooks
```

Each environment is an independent root module with its own state. Both compose the same `app_environment`
module, so they differ only in their inputs. The load balancer and the database instance are shared to keep the
cost near the budget ([ADR-0003](docs/adr/0003-share-the-load-balancer-and-database-between-environments.md)).
Architecture: [AWS architecture](docs/architecture/aws.md). How to apply: [runbook](docs/runbooks/apply-environments.md).

## Remote state

All states live in the S3 bucket `silversoft-silver-proposals-tfstate-v2` (us-east-2), one key per root module
(`bootstrap/`, `staging/`, `prod/`), with versioning, encryption, TLS-only access, and **S3 native locking**
(`use_lockfile`), so no DynamoDB table is needed. Only the operators and each environment's CI role can reach the
bucket, and a CI role only its own environment's state. Design: [ADR-0002](docs/adr/0002-terraform-state-in-s3-with-native-locking.md).
How the bucket was created and how to recover it: [state bootstrap runbook](docs/runbooks/terraform-state-bootstrap.md).

## Requirements

- [Terraform](https://developer.hashicorp.com/terraform/install) `>= 1.10, < 2.0` (S3 native state locking)
- AWS CLI v2, signed in with `aws login` as an operator (the `managed/AccountFullAccessRole` role, temporary credentials, no access keys, never root)
- [tflint](https://github.com/terraform-linters/tflint) (Git hooks)

## Quick start

```bash
aws sts get-caller-identity   # must be the operator role
cd environments/staging
terraform init                # connects to the remote state
terraform plan
```

## CI/CD

GitHub Actions with OIDC (no AWS keys): checks and scans on every pull request, `terraform plan` for each root
module on the pull request, automatic apply to staging after a merge, and apply with approval for shared and
production. Releases follow semantic versioning. Details: [CI/CD](docs/reference/ci-cd.md).
How a change reaches production: [release to production](docs/runbooks/release-to-production.md).

| Environment | App | API |
|---|---|---|
| staging | <https://app-staging.silversoft.com.br> | <https://api-staging.silversoft.com.br> |
| prod | <https://app.silversoft.com.br> | <https://api.silversoft.com.br> |

## Contributing

Install the Git hooks before your first commit:

```bash
uv tool install pre-commit   # or: pipx install pre-commit
pre-commit install
```

Branch, commit, and pull request conventions are in [CONTRIBUTING.md](CONTRIBUTING.md).
Security issues: see [SECURITY.md](SECURITY.md).

## Documentation

See [docs/README.md](docs/README.md).
