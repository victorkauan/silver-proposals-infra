# Outputs contract

The infra repository owns every cloud resource. The backend and frontend pipelines learn where to deploy
from the Terraform outputs below, which are stored as **GitHub Actions variables** in a GitHub environment
(`staging` or `production`) of the consuming repository.

They are variables, not secrets, because none of them is a credential. Authentication uses GitHub OIDC,
so the only sensitive value a workflow needs is the role to assume, and a role ARN grants nothing by itself.

> **Status:** planned. The outputs are created with the Terraform modules and the CI/CD setup.

## Backend

| Terraform output | GitHub variable | Used for |
|---|---|---|
| `backend_deploy_role_arn` | `AWS_DEPLOY_ROLE_ARN` | OIDC role assumed by the deploy workflow |
| `ecr_repository_url` | `ECR_REPOSITORY_URL` | Image push target |
| `ecs_cluster_name` | `ECS_CLUSTER` | Rollout target |
| `ecs_service_name` | `ECS_SERVICE` | Rollout target |
| — | `AWS_REGION` | Always `us-east-1` |

## Frontend

| Terraform output | GitHub variable | Used for |
|---|---|---|
| `frontend_deploy_role_arn` | `AWS_DEPLOY_ROLE_ARN` | OIDC role assumed by the deploy workflow |
| `frontend_bucket_name` | `S3_BUCKET` | Static assets upload target |
| `cloudfront_distribution_id` | `CLOUDFRONT_DISTRIBUTION_ID` | Cache invalidation after upload |
| `api_base_url` | `VITE_API_BASE_URL` | API address embedded at build time |
| — | `AWS_REGION` | Always `us-east-1` |

## Propagation

After `terraform apply`, the values are written to the consuming repositories' GitHub environments.
Whether this is done manually or by Terraform itself is decided with the CI/CD setup.
