# Release to production

Every change reaches production through the same path: merge to `main`, automatic deploy to staging, check
staging, then approve production in GitHub. Nobody deploys from a laptop.

| Environment | App | API |
|---|---|---|
| staging | <https://app-staging.silversoft.com.br> | <https://api-staging.silversoft.com.br> |
| prod | <https://app.silversoft.com.br> | <https://api.silversoft.com.br> |

## Flow

1. **Merge the pull request** (all required checks green).
2. **Staging deploys automatically.**
   - Infra: the Deploy workflow applies `staging` (and `shared` after approval, only if it changed).
   - Backend: after CI passes, Deploy builds the image once, pushes `<repository>:<commit sha>` to ECR, registers
     a task definition revision, runs `alembic upgrade head` as a one-off task, rolls out, and checks `/ready`.
   - Frontend: after CI passes, Deploy builds with the staging API URL, publishes to S3, invalidates CloudFront,
     and checks the page.
3. **Check staging** for the change: at least `GET /ready`, sign-in, and the feature that changed. For changes to
   generation, run one generation (it calls Amazon Bedrock and costs a fraction of a cent).
4. **Approve production.** Open the Deploy run → **Review deployments** → `prod` → **Approve and deploy**. The same
   commit is deployed; the backend reuses the staging image (the production role cannot push images).
5. **Check production:** `curl https://api.silversoft.com.br/ready` returns `{"status":"ready"}` and
   `https://app.silversoft.com.br` loads.

Approvals are recorded in each run (who, when, comment).

## Database migrations

Migrations run before the rollout, as a one-off Fargate task with the new image and the environment's
`DATABASE_URL`. If they fail, the deploy stops and the running version keeps serving. Migrations must stay
backward compatible with the version that is still running (add first, remove in a later release).

## Two-factor authentication rollout

Apply the infrastructure change in staging and production before deploying the backend release that requires
`TOTP_ENCRYPTION_KEY`. The backend deploy copies the latest task definition before running migrations, so that
revision must already reference the key in Secrets Manager. Deploy the backend before the frontend, whose browser
tests run against the backend's main branch.

Keep the encryption key with the corresponding database backups. Replacing the key by itself makes existing
authenticator secrets unreadable and invalidates the corresponding recovery codes.

## Rollback

| What | How |
|---|---|
| A rollout that fails its health checks | The ECS circuit breaker rolls back to the previous task definition automatically. |
| A bad backend release | Re-run the Deploy workflow (**Run workflow**) on the last good commit, or update the service to the previous task definition revision. Database changes are not rolled back automatically. |
| A bad frontend release | Re-run the frontend Deploy workflow on the last good commit. |
| A bad infrastructure change | Revert the pull request; the revert goes through the same plan, apply, and approvals. |

## First release (2026-11-18)

| Step | Evidence |
|---|---|
| Infra applied by CI (staging automatic, prod after approval) | [Deploy 44368912608](https://github.com/victorkauan/silver-proposals-infra/actions/runs/44368912608) |
| Backend `c45cb13`: staging, then prod after approval | [Deploy 44373161444](https://github.com/victorkauan/silver-proposals-backend/actions/runs/44373161444) |
| Frontend `b848041`: staging, then prod after approval | [Deploy 44373353037](https://github.com/victorkauan/silver-proposals-frontend/actions/runs/44373353037) |

Staging was checked end to end before production was approved: sign-up and login, generation with Amazon Nova
2 Lite through the task role (`generation_completed`, 375 input and 777 output tokens), editing (version 2), the
`409` conflict on a stale save, history, and a share link that worked and returned `404` after being revoked.
