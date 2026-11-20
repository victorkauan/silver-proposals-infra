#!/bin/sh
set -eu

test -s /backup/database.dump
timestamp=$(date -u +%Y-%m-%dT%H%M%S)
read -r backup_id < /proc/sys/kernel/random/uuid
aws s3 cp /backup/database.dump "s3://${BACKUP_BUCKET}/dumps/${timestamp}-${backup_id}.dump" \
  --sse AES256 --only-show-errors --no-progress
echo "database backup uploaded"
