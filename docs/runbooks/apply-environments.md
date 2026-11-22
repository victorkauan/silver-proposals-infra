# Apply the AWS environments

The root modules are applied in this order, because each one reads the state of the previous one:

| Order | Folder | State key | Creates |
|---|---|---|---|
| 1 | `bootstrap/` | `bootstrap/` | the state bucket (done once, see the [state bootstrap](terraform-state-bootstrap.md)) |
| 2 | `environments/shared/` | `shared/` | network, ALB, RDS, ECR, budget |
| 3 | `environments/staging/` | `staging/` | staging app and API |
| 4 | `environments/prod/` | `prod/` | production app and API (approval required) |

Changes to `shared` affect both environments, so they need the same care as production
([ADR-0003](../adr/0003-share-the-load-balancer-and-database-between-environments.md)).

## Prerequisites

- Signed in as an operator: `aws sts get-caller-identity` shows `assumed-role/AccountFullAccessRole`, never root.
- A **Cloudflare API token** scoped to DNS of `silversoft.com.br` only:
  Cloudflare dashboard → My Profile → API Tokens → Create Token → *Create Custom Token* with the permissions
  **Zone → DNS → Edit** and **Zone → Zone → Read**, and Zone Resources **Include → Specific zone →
  silversoft.com.br**. Export it in the shell; never write it to a file:

  ```bash
  read -rs CLOUDFLARE_API_TOKEN && export CLOUDFLARE_API_TOKEN
  ```

- The budget alert addresses for `shared`, also only in the shell:

  ```bash
  export TF_VAR_budget_alert_emails='["you@example.com"]'
  ```

## Apply

```bash
cd environments/shared
terraform init
terraform plan -out=shared.tfplan
terraform apply shared.tfplan

cd ../staging
terraform init
terraform plan -out=staging.tfplan
terraform apply staging.tfplan
```

The staging and production applies run a one-off Fargate task that creates the environment's database and role
on the shared instance (`modules/api_service/scripts/run-task.sh`). It needs the AWS CLI and fails the apply if
the task does not exit with code 0. Its output is in the environment's API log group (stream prefix `db-setup`).

The API service starts with `desired_count = 0`, because no image exists yet. The deploy pipeline publishes the
first image and sets `image_tag` and `desired_count`.

## After the apply

- `terraform output` lists the values for the backend and frontend repositories
  ([outputs contract](../reference/outputs-contract.md)).
- ACM certificates are validated through the Cloudflare records in a few minutes; the apply waits for them.
- The budget sends a confirmation e-mail only when an alert fires; there is nothing to confirm in advance.
- With `ai_provider = "deepinfra"`, the first apply creates an empty secret `silver-proposals-<environment>/deepinfra`.
  Set the key before the backend deploys the new task definition, or the task cannot start:

  ```bash
  aws secretsmanager put-secret-value --region us-east-2 \
    --secret-id silver-proposals-staging/deepinfra --secret-string "$(tr -d '[:space:]' < deepinfra.key)"
  ```

  Replace a leaked key the same way, then run the backend deploy again so new tasks read it.

## AWS Free plan

The account runs on the AWS Free plan, which rejects some settings with `FreeTierRestrictionError`. Known so far:

| Setting | Free plan limit | Where |
|---|---|---|
| RDS automated backup retention | 1 day (the module default is 7) | `environments/shared/main.tf` |

On a Paid plan, remove the override to return to the defaults.

The account is a *project account* of the new AWS sign-up experience, so AWS-managed policies add these limits
([ADR-0005](../adr/0005-move-to-a-project-account-in-us-east-2.md)):

| Limit | Consequence |
|---|---|
| Regional services only in us-east-2 (us-east-1 allows global services only) | Everything runs in us-east-2; CloudFront certificates stay in us-east-1 |
| No console passwords for IAM users | Operators use `aws login` with the `managed/AccountFullAccessRole` role |
| No CloudWatch alarms in us-east-1 | No alarm on the CloudFront metrics; the dashboard charts them |

## Moving to another account

No account ID is hard-coded, so the code moves as is. In order:

1. Check the new account's limits (region, IAM users) before anything else, and sign in as the operator.
2. Bucket names are global: if the old account still holds them, pick new names (state and frontend buckets).
3. Run the [state bootstrap](terraform-state-bootstrap.md) locally, then update the infra repository variable
   `TERRAFORM_ROLE_ARN_PREFIX` with the new account's role ARN prefix.
4. Set the infra variable `INITIALIZE_APP_SECRET=true` so the first staging and prod applies create the application
   secrets, and keep it. The values are written only once (`secret_string_wo_version = 1`); setting it back to `false`
   makes the plans try to destroy the secret version, which `prevent_destroy` refuses.
5. Apply `shared`, `staging`, and `prod` through the pipeline, then publish the outputs to the backend and frontend
   repositories (`scripts/publish-outputs.sh`) and run their deploys.
6. Confirm the SNS alert subscription e-mail again.

If the old account can no longer be changed, its DNS records and CloudFront aliases stay behind:

- Delete the old `app`, `api`, `app-staging`, and `api-staging` CNAME records in Cloudflare first (Cloudflare error
  81053: a record with that host already exists).
- CloudFront aliases are global, so the old distributions keep the app host names (`CNAMEAlreadyExists`). Apply with
  `attach_app_host_name = false` (the distribution is created with its certificate but no alias, plus a
  `_<host>` TXT record pointing to it), move each name, then set it back to `true` and apply again:

  ```bash
  aws cloudfront associate-alias --target-distribution-id <new id> --alias app-staging.silversoft.com.br
  ```

## Troubleshooting

| Symptom | What to do |
|---|---|
| `Unable to find remote state` in staging or prod | Apply `environments/shared` first. |
| Cloudflare `Authentication error` | `CLOUDFLARE_API_TOKEN` is missing in this shell, or the token lacks Zone Read or DNS Edit on the zone. |
| The database setup task fails | Read the `db-setup` stream in the API log group; then run `terraform apply` again (the task is idempotent). |
| `DBInstance ... deletion protection` on destroy | Intentional. Disable `deletion_protection` in a reviewed change first. |
| `FreeTierRestrictionError` | A setting exceeds the Free plan; see the section above, lower it with a comment, and re-apply (resources already created are kept). |
