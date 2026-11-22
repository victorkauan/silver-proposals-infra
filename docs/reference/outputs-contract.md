# Outputs contract

The infra repository owns every cloud resource. The backend and frontend pipelines learn where to deploy
from the Terraform outputs below, which are stored as **GitHub Actions variables** in a GitHub environment
(`staging` or `production`) of the consuming repository.

They are variables, not secrets, because none of them is a credential. Authentication uses GitHub OIDC,
so the only sensitive value a workflow needs is the role to assume, and a role ARN grants nothing by itself.

> **Status:** live. The deploy roles are created by each environment, and `scripts/publish-outputs.sh <env>` writes
> the values to the backend and frontend GitHub environments `staging` and `prod`.

## Backend

| Terraform output | GitHub variable | Used for |
|---|---|---|
| `backend_deploy_role_arn` | `AWS_DEPLOY_ROLE_ARN` | OIDC role assumed by the deploy workflow (pushes images only in staging) |
| `ecr_repository_url` (shared) | `ECR_REPOSITORY_URL` | Image push target, shared by both environments |
| `ecs_cluster_name` | `ECS_CLUSTER` | Rollout target |
| `ecs_service_name` | `ECS_SERVICE` | Rollout target |
| `ecs_task_definition_family` | `ECS_TASK_DEFINITION_FAMILY` | Family of the new task definition revision |
| `ecs_subnet_ids` | `ECS_SUBNETS` | Subnets of the one-off migrations task (comma-separated) |
| `ecs_task_security_group_id` | `ECS_SECURITY_GROUP` | Security group of the migrations task |
| `api_url` | `API_URL` | Smoke test after deploy |
| — | `AWS_REGION` | Always `us-east-2` |

## Frontend

| Terraform output | GitHub variable | Used for |
|---|---|---|
| `frontend_deploy_role_arn` | `AWS_DEPLOY_ROLE_ARN` | OIDC role assumed by the deploy workflow |
| `frontend_bucket_name` | `S3_BUCKET` | Static assets upload target |
| `cloudfront_distribution_id` | `CLOUDFRONT_DISTRIBUTION_ID` | Cache invalidation after upload |
| `api_url` | `VITE_API_BASE_URL` | API address embedded at build time |
| `app_url` | `APP_URL` | Smoke test after deploy |
| — | `AWS_REGION` | Always `us-east-2` |

## Other outputs

Per environment: `app_url`, `ecs_task_role_arn`, `ecs_execution_role_arn`, `api_log_group_name`, and
`app_secret_arn` (for operators and the CI roles). The `shared` root module also outputs the network, load balancer,
database, and Cloudflare zone values that the environments read through `terraform_remote_state`.

## Propagation

After an apply, an operator runs `scripts/publish-outputs.sh staging` (or `prod`). It reads `terraform output`
and writes the variables to the matching GitHub environment of each repository with the GitHub CLI. Terraform
does not write them itself, because that would need a long-lived GitHub token in the pipeline.

The backend pipeline owns image rollouts: Terraform creates the ECS service and a baseline task definition and then
ignores `task_definition` and `desired_count`. Each deploy registers a revision from the latest one (so Terraform's
configuration changes are kept) with the new image.
