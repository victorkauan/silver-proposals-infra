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

- Signed in as an operator: `aws sts get-caller-identity` shows the operator user, never root.
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

## AWS Free plan

The account runs on the AWS Free plan, which rejects some settings with `FreeTierRestrictionError`. Known so far:

| Setting | Free plan limit | Where |
|---|---|---|
| RDS automated backup retention | 1 day (the module default is 7) | `environments/shared/main.tf` |

On a Paid plan, remove the override to return to the defaults. Moving to another account needs, in order: an
operator user with MFA and no access keys, Bedrock model access, the state bootstrap (the state bucket name is
global, so pick a new one or delete the old bucket first), then `shared`, `staging`, and `prod`. No account ID is
hard-coded, so the code moves as is.

## Troubleshooting

| Symptom | What to do |
|---|---|
| `Unable to find remote state` in staging or prod | Apply `environments/shared` first. |
| Cloudflare `Authentication error` | `CLOUDFLARE_API_TOKEN` is missing in this shell, or the token lacks Zone Read or DNS Edit on the zone. |
| The database setup task fails | Read the `db-setup` stream in the API log group; then run `terraform apply` again (the task is idempotent). |
| `DBInstance ... deletion protection` on destroy | Intentional. Disable `deletion_protection` in a reviewed change first. |
| `FreeTierRestrictionError` | A setting exceeds the Free plan; see the section above, lower it with a comment, and re-apply (resources already created are kept). |
