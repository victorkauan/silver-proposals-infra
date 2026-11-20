# Restore a database backup

EventBridge Scheduler starts one staging Fargate dump at 06:00 UTC and one production dump at 06:30 UTC. The PostgreSQL 17 client writes a custom-format dump for its own database, checks the archive catalog and hands it to a separate upload container. The task role can upload only below its environment's `dumps/` prefix. The operator can retrieve a dump over HTTPS. Lifecycle expiry is 14 days. RDS snapshots remain available under the RDS retention setting.

1. Identify the last good encrypted object in the environment's backup bucket and record its timestamp. Check the corresponding `backup/` log streams if an object is missing. Scheduler retries ECS task launch. Diagnose a failed container through ECS stopped task reasons and its logs.
2. Use a private, isolated PostgreSQL 17 target and authorized restore credentials. Create an empty database dedicated to the drill. Protect the temporary files and use your normal credential mechanism, such as an operator-controlled PostgreSQL password file with mode 0600.

   ```sh
   umask 077
   restore_dir=$(mktemp -d)
   aws s3 cp "s3://${BACKUP_BUCKET}/${BACKUP_KEY}" "$restore_dir/database.dump" --only-show-errors
   pg_restore --list "$restore_dir/database.dump" > "$restore_dir/catalog.txt"
   pg_restore --exit-on-error --no-owner --no-privileges --dbname="$RESTORE_DATABASE" "$restore_dir/database.dump"
   psql -X --set=ON_ERROR_STOP=1 --dbname="$RESTORE_DATABASE" \
     -c 'SELECT (SELECT count(*) FROM proposals) AS proposals, (SELECT count(*) FROM proposal_versions) AS versions;'
   ```

3. Compare counts as of the backup timestamp. Verify that a known proposal has the expected version history. Use synthetic staging data for the drill. Record backup age, start and finish timestamps, and the outcome without including raw user data. If checking a restored login, provide the original TOTP encryption key through Secrets Manager and keep the target application private. For a real recovery, pause writes and get approval before any production cutover.
4. Remove the drill database and the local archive and catalog after verification. Store only the sanitized evidence.

The `*-backup-missing` alarm emails the shared SNS topic after two missing daily periods. Following an intentional database stop, resume it and confirm the next successful upload. A local restore verifies the dump format and schema/data recovery. The AWS drill verifies delivery and operational access. [EventBridge Scheduler ECS targets](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/tasks-scheduled-eventbridge-scheduler.html).
