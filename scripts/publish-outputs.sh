#!/usr/bin/env bash
# Copies an environment's Terraform outputs into the GitHub environment variables of the backend and
# frontend repositories (see docs/reference/outputs-contract.md). Run by an operator after an apply,
# signed in to AWS and to the GitHub CLI with admin access to both repositories.
set -euo pipefail

env_name="${1:?usage: scripts/publish-outputs.sh <staging|prod>}"
owner="${GITHUB_OWNER:-victorkauan}"
root="$(cd "$(dirname "$0")/.." && pwd)"

case "$env_name" in staging | prod) ;; *) echo "environment must be staging or prod" >&2; exit 1 ;; esac

shared=$(terraform -chdir="$root/environments/shared" output -json)
outputs=$(terraform -chdir="$root/environments/$env_name" output -json)
value() {
  python3 -c 'import json, sys
v = json.loads(sys.argv[1])[sys.argv[2]]["value"]
print(",".join(v) if isinstance(v, list) else v)' "$1" "$2"
}

set_vars() {
  local repo="$1"; shift
  gh api --silent --method PUT "repos/$owner/$repo/environments/$env_name" >/dev/null
  while [ "$#" -gt 0 ]; do
    gh variable set "$1" --repo "$owner/$repo" --env "$env_name" --body "$2"
    echo "  $repo [$env_name] $1"
    shift 2
  done
}

set_vars silver-proposals-backend \
  AWS_REGION us-east-1 \
  AWS_DEPLOY_ROLE_ARN "$(value "$outputs" backend_deploy_role_arn)" \
  ECR_REPOSITORY_URL "$(value "$shared" ecr_repository_url)" \
  ECS_CLUSTER "$(value "$outputs" ecs_cluster_name)" \
  ECS_SERVICE "$(value "$outputs" ecs_service_name)" \
  ECS_TASK_DEFINITION_FAMILY "$(value "$outputs" ecs_task_definition_family)" \
  ECS_SUBNETS "$(value "$outputs" ecs_subnet_ids)" \
  ECS_SECURITY_GROUP "$(value "$outputs" ecs_task_security_group_id)" \
  API_URL "$(value "$outputs" api_url)"

set_vars silver-proposals-frontend \
  AWS_REGION us-east-1 \
  AWS_DEPLOY_ROLE_ARN "$(value "$outputs" frontend_deploy_role_arn)" \
  S3_BUCKET "$(value "$outputs" frontend_bucket_name)" \
  CLOUDFRONT_DISTRIBUTION_ID "$(value "$outputs" cloudfront_distribution_id)" \
  VITE_API_BASE_URL "$(value "$outputs" api_url)" \
  APP_URL "$(value "$outputs" app_url)"
