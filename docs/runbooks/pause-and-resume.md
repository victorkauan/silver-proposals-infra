# Pause and resume the project

Stops both environments and the shared database to save costs while nobody uses the application, and brings them
back. Run it from the repository root, signed in to AWS with an administrator user (never root).

```bash
scripts/environment-power.sh status   # database, ECS services, alarms
scripts/environment-power.sh pause
scripts/environment-power.sh resume   # about 10 to 15 minutes
```

## Pause

1. Turns off the actions of every `silver-proposals-*` alarm, because stopping the services makes `api-down` and
   `alb-5xx` fire.
2. Sets the staging and prod API services to 0 tasks and waits for them to drain.
3. Stops the database.

The load balancer, the public IPv4 addresses it uses, CloudFront, S3, and the secrets keep running and billing; the
frontends stay online, and the API answers `503`. AWS **starts a stopped database again by itself after 7 days**,
so pause again if needed.

## Resume

1. Starts the database and waits until it is available.
2. Sets both API services to 1 task and waits until they are stable.
3. Checks `/ready` on `api-staging.silversoft.com.br` and `api.silversoft.com.br`.
4. Waits 6 minutes so the alarms see healthy data, then turns their actions back on.

An alarm that recovers after step 4 still sends its "OK" e-mail; that is expected.

## Notes

- Terraform ignores the services' desired count, so a pause does not show up as drift in the plans.
- Do not run an infra or backend deploy while paused: database setup and migrations need the database.
- To silence alarms without pausing (for example during maintenance), use
  `aws cloudwatch disable-alarm-actions` and `enable-alarm-actions` with the alarm names.
