#!/usr/bin/env bash
# Runs a one-off Fargate task and fails unless its container exits with code 0.
set -euo pipefail

task_arn=$(aws ecs run-task \
  --region "$AWS_REGION" \
  --cluster "$CLUSTER" \
  --task-definition "$TASK_DEFINITION" \
  --launch-type FARGATE \
  --network-configuration "awsvpcConfiguration={subnets=[$SUBNETS],securityGroups=[$SECURITY_GROUP],assignPublicIp=ENABLED}" \
  --query 'tasks[0].taskArn' --output text)

echo "started $task_arn"
aws ecs wait tasks-stopped --region "$AWS_REGION" --cluster "$CLUSTER" --tasks "$task_arn"

exit_code=$(aws ecs describe-tasks --region "$AWS_REGION" --cluster "$CLUSTER" --tasks "$task_arn" \
  --query 'tasks[0].containers[0].exitCode' --output text)
reason=$(aws ecs describe-tasks --region "$AWS_REGION" --cluster "$CLUSTER" --tasks "$task_arn" \
  --query 'tasks[0].stoppedReason' --output text)

echo "exit code: $exit_code ($reason)"
[ "$exit_code" = "0" ]
