# Outputs contract

The infra repository owns every cloud resource. The backend and frontend pipelines learn where to deploy
from the Terraform outputs below, which are stored as **GitHub Actions variables** in a GitHub environment
(`staging` or `production`) of the consuming repository.

They are variables, not secrets, because none of them is a credential. Authentication uses GitHub OIDC,
so the only sensitive value a workflow needs is the role to assume, and a role ARN grants nothing by itself.

> **Status:** the outputs exist (SIL-219). Writing them to the GitHub environments, and the deploy roles, come with the CI/CD setup.

## Backend

| Terraform output | GitHub variable | Used for |
|---|---|---|
| `backend_deploy_role_arn` | `AWS_DEPLOY_ROLE_ARN` | OIDC role assumed by the deploy workflow (CI/CD setup) |
| `ecr_repository_url` (shared) | `ECR_REPOSITORY_URL` | Image push target, shared by both environments |
| `ecs_cluster_name` | `ECS_CLUSTER` | Rollout target |
| `ecs_service_name` | `ECS_SERVICE` | Rollout target |
| `ecs_task_definition_family` | `ECS_TASK_DEFINITION_FAMILY` | Family of the new task definition revision |
| `api_url` | — | Smoke test after deploy |
| — | `AWS_REGION` | Always `us-east-1` |

## Frontend

| Terraform output | GitHub variable | Used for |
|---|---|---|
| `frontend_deploy_role_arn` | `AWS_DEPLOY_ROLE_ARN` | OIDC role assumed by the deploy workflow (CI/CD setup) |
| `frontend_bucket_name` | `S3_BUCKET` | Static assets upload target |
| `cloudfront_distribution_id` | `CLOUDFRONT_DISTRIBUTION_ID` | Cache invalidation after upload |
| `api_url` | `VITE_API_BASE_URL` | API address embedded at build time |
| — | `AWS_REGION` | Always `us-east-1` |

## Other outputs

Per environment: `app_url`, `ecs_task_role_arn`, `ecs_execution_role_arn`, `api_log_group_name`, and
`app_secret_arn` (for operators and the CI roles). The `shared` root module also outputs the network, load balancer,
database, and Cloudflare zone values that the environments read through `terraform_remote_state`.

## Propagation

After `terraform apply`, the values are written to the consuming repositories' GitHub environments.
Whether this is done manually or by Terraform itself is decided with the CI/CD setup.
