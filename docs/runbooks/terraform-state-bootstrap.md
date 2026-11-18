# Terraform state bootstrap

The state bucket `silversoft-silver-proposals-tfstate` holds every Terraform state of the project. It is created once
by the `bootstrap/` root module. Why it is designed this way: [ADR-0002](../adr/0002-terraform-state-in-s3-with-native-locking.md).

| Key | Root module |
|---|---|
| `bootstrap/terraform.tfstate` | `bootstrap/` (the bucket itself) |
| `staging/terraform.tfstate` | `environments/staging/` |
| `prod/terraform.tfstate` | `environments/prod/` |

## Prerequisites

- Terraform `>= 1.10` and AWS CLI v2.
- Signed in as an operator listed in `operator_user_names` (`aws login`, an IAM user with MFA and no access keys).
  Never run Terraform as the root user.
- `aws sts get-caller-identity` shows the operator user.

## First-time setup

This was done once on 2026-11-18. Repeat it only to rebuild the bucket from scratch.

1. Move the backend block out of the way, because the bucket does not exist yet:

   ```bash
   cd bootstrap
   mv backend.tf backend.tf.off
   terraform init
   terraform plan -out=bootstrap.tfplan    # review: 7 to add
   terraform apply bootstrap.tfplan
   ```

2. Put the backend block back and copy the local state into the bucket (answer `yes`):

   ```bash
   mv backend.tf.off backend.tf
   terraform init -migrate-state
   terraform plan                          # must say "No changes"
   rm terraform.tfstate terraform.tfstate.backup bootstrap.tfplan
   ```

3. Initialize each environment:

   ```bash
   cd ../environments/staging && terraform init
   cd ../prod && terraform init
   ```

## GitHub OIDC provider

The bootstrap also creates the GitHub Actions OIDC provider, the workload permissions boundary, and the Terraform CI
roles ([CI/CD](../reference/ci-cd.md)). An AWS account can hold only one OIDC provider per URL. If the account
already has one for `https://token.actions.githubusercontent.com` (for example from another project), import it
before the first apply instead of creating a duplicate:

```bash
cd bootstrap
account=$(aws sts get-caller-identity --query Account --output text)
terraform import aws_iam_openid_connect_provider.github \
  "arn:aws:iam::${account}:oidc-provider/token.actions.githubusercontent.com"
```

Terraform then only adds the project tags; roles of other projects that trust the provider keep working, and the
provider has `prevent_destroy`.

## Daily use

Run `terraform init` once per environment folder, then `plan` and `apply` as usual. Every command that writes the
state takes the lock first, so a second run fails with `Error acquiring the state lock` until the first one finishes.

## Troubleshooting

| Symptom | What to do |
|---|---|
| `Error acquiring the state lock` and no other run is active | A run was interrupted. Check the lock info (who, when), then `terraform force-unlock <ID>` from the same folder. |
| `AccessDenied ... explicit deny in a resource-based policy` | You are not an allowed principal, or the request did not use TLS. Check `aws sts get-caller-identity`. |
| A state was overwritten or deleted by mistake | Restore a previous version of the object (versions are kept for 90 days): `aws s3api list-object-versions --bucket silversoft-silver-proposals-tfstate --prefix <env>/`, then copy the version back. |
| The bucket policy locks everyone out | Sign in as the root user (MFA), fix or delete the bucket policy, then run `terraform apply` in `bootstrap/` to restore it. |

## Verification (2026-11-18)

- Versioning `Enabled`, encryption `AES256`, all four public access blocks on, object ownership `BucketOwnerEnforced`.
- A request over plain HTTP from the operator was refused with an explicit deny from the bucket policy.
- While one `terraform apply` waited for confirmation in staging, a second `terraform plan -lock-timeout=0` failed with
  `Error acquiring the state lock` (S3 `412 PreconditionFailed` on `staging/terraform.tfstate.tflock`).
