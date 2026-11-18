# CI/CD

All workflows authenticate to AWS with **GitHub OIDC**; there are no AWS access keys in GitHub. Every third-party
action is pinned to a commit SHA, and scanner images are pinned by digest.

## Workflows

| Workflow | Trigger | What it does |
|---|---|---|
| [CI](../../.github/workflows/ci.yml) | pull request, push to `main` | `quality` (fmt, validate, tflint), `security` (Checkov, Trivy, gitleaks), and on pull requests `plan` for `shared`, `staging`, and `prod`, with the plan in the job summary and a comment on the PR |
| [Deploy](../../.github/workflows/deploy.yml) | push to `main`, manual | `shared` is planned; if it has changes it is applied after approval. `staging` is applied automatically. `prod` is applied after approval |
| [Terraform apply](../../.github/workflows/terraform-apply.yml) | called by Deploy | plan and apply of one root module, inside its GitHub environment |
| [Release](../../.github/workflows/release.yml) | push to `main` | semantic-release: `feat` → minor, `fix` → patch, `!` → major; tag `vX.Y.Z` and a GitHub Release |
| [PR title](../../.github/workflows/pr-title.yml) | pull request | Conventional Commits title ending with `[SIL-<n>]` |

## Identities

| Role | Assumed by (OIDC subject) | Permissions |
|---|---|---|
| `silver-proposals-terraform-<root>-plan` | `repo:victorkauan/silver-proposals-infra:pull_request` and `:ref:refs/heads/main` | `ReadOnlyAccess`, its own state (read/write, for the lock), the shared state (read), and the app secrets (plans refresh secret versions) |
| `silver-proposals-terraform-<root>` | `repo:victorkauan/silver-proposals-infra:environment:<root>` | `PowerUserAccess`, IAM only for `silver-proposals-*` roles that carry the workload boundary, its own state and the shared state |
| `silver-proposals-<env>-deploy-backend` | `repo:victorkauan/silver-proposals-backend:environment:<env>` | ECR (push only in staging), task definitions, its ECS service, migrations task, pass its two task roles |
| `silver-proposals-<env>-deploy-frontend` | `repo:victorkauan/silver-proposals-frontend:environment:<env>` | its S3 bucket and CloudFront invalidations |

`<root>` is `shared`, `staging`, or `prod`; `<env>` is `staging` or `prod`. The Terraform roles and the OIDC
provider live in `bootstrap/` and are applied by an operator; the deploy roles are created by each environment.

Guard rails:

- A pull request can only plan. Applying needs a job in the protected GitHub environment, which only
  `deploy.yml` on `main` runs, and `shared` and `prod` need a reviewer's approval.
- **Permissions boundary.** Every role Terraform creates must carry `silver-proposals-workload-boundary`. The apply
  roles cannot create roles without it, remove it, or change it, so they cannot create a role more powerful than the
  workloads need (no privilege escalation through IAM).
- The apply roles are denied any change to the CI roles, the OIDC provider, and the state bucket's configuration.
- The state bucket policy confines each root's roles to their own state, plus read access to `shared/`.

## Secrets and variables

| Name | Kind | Used by |
|---|---|---|
| `CLOUDFLARE_API_TOKEN` | repository secret | Terraform plan and apply only (Cloudflare provider). The token is scoped to DNS of `silversoft.com.br` |
| `BUDGET_ALERT_EMAILS` | repository secret | Terraform plan and apply of `shared` (JSON list) |
| `TERRAFORM_ROLE_ARN_PREFIX` | repository variable | `arn:aws:iam::<account>:role/silver-proposals-terraform`; the workflows add `-<root>` or `-<root>-plan` |

The Terraform outputs reach the backend and frontend repositories as GitHub environment variables, written by
`scripts/publish-outputs.sh <env>` after an apply ([outputs contract](outputs-contract.md)).

## Failure policy for security findings

| Scanner | Scope | Fails the job on |
|---|---|---|
| Checkov 3.4.3 | Terraform | any failed check |
| Trivy 0.76.1 (`config`) | Terraform misconfigurations | any HIGH or CRITICAL finding |
| gitleaks 8.30.1 | full Git history | any secret |

A finding is never ignored silently. An accepted risk is suppressed next to the resource with the reason
(`#checkov:skip=<ID>:<reason>` or `#trivy:ignore:<ID> <reason>`), so it is reviewed in the pull request like any
other change. Typical reasons are cost (KMS keys, WAF, Multi-AZ) and documented decisions (no NAT Gateway,
single region). Findings of MEDIUM or LOW severity in Trivy are reported but do not fail the job.

## Branch protection

Ruleset `main-protection`: pull request required (squash only), no force pushes or deletions, and the checks
`quality`, `security`, `plan (shared)`, `plan (staging)`, `plan (prod)`, and `pr-title` must pass on an up-to-date
branch.
