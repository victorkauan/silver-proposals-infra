# Silver Proposals — Infrastructure

Infrastructure as code for **Silver Proposals**, an AI-powered SaaS for creating and managing commercial proposals.
This repo defines the AWS resources (us-east-1) and Cloudflare DNS records that the application runs on,
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
environments/
  staging/        # root module for staging (app-staging / api-staging.silversoft.com.br)
  prod/           # root module for production (app / api.silversoft.com.br)
modules/          # reusable modules shared by both environments
docs/             # architecture, ADRs, guides, reference, runbooks
```

Each environment is an independent root module with its own state. Both compose the same modules, so the
environments differ only in their inputs.

## Requirements

- [Terraform](https://developer.hashicorp.com/terraform/install) `>= 1.9, < 2.0`

## Quick start

```bash
cd environments/staging
terraform init
terraform validate
```

## Documentation

See [docs/README.md](docs/README.md).
