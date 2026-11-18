---
status: accepted
date: 2026-11-18
decision-makers: Victor Kauan
---

# Keep Terraform state in one S3 bucket with native S3 locking

## Context and Problem Statement

Terraform needs a remote state that the operator's workstation and, later, CI can share. The state must survive
mistakes, must not be readable by anyone else, and staging must never be able to change production's state. Where do
we store the state, and how do we prevent two runs from writing it at the same time?

## Decision Drivers

- Isolation between staging and production, and least privilege for CI.
- Recovery from a bad write or an accidental deletion.
- No long-lived credentials and no secrets in Git.
- Close to zero cost and few moving parts for a single maintainer.

## Considered Options

- S3 bucket with a DynamoDB table for locking
- S3 bucket with S3 native locking (`use_lockfile`)
- HCP Terraform (Terraform Cloud) remote state

## Decision Outcome

Chosen option: **one S3 bucket with S3 native locking**. Since Terraform 1.10, the S3 backend locks the state by
writing a `<key>.tflock` object with a conditional write, so a second run gets `412 PreconditionFailed` and stops.
HashiCorp deprecated DynamoDB-based locking in favor of this, so it removes a resource and its IAM permissions without
losing any guarantee. HCP Terraform would add an external account and a token to manage.

- **Layout:** `bootstrap/terraform.tfstate`, `staging/terraform.tfstate`, and `prod/terraform.tfstate` in
  `silversoft-silver-proposals-tfstate` (us-east-1). Each environment is its own root module with its own key.
- **Protection:** versioning (previous versions kept for 90 days), SSE-S3 encryption, all public access blocked, ACLs
  disabled, and `prevent_destroy` on the bucket.
- **Access:** the bucket policy denies requests without TLS and denies every principal except the operators and the CI
  Terraform roles `silver-proposals-terraform-<environment>`. Each CI role is denied every object outside its own
  `<environment>/` prefix, so staging's pipeline cannot read or write production's state, nor the bootstrap state.
- **Bootstrap:** the bucket is created by its own root module (`bootstrap/`), first with local state, which is then
  migrated into the bucket. See the [runbook](../runbooks/terraform-state-bootstrap.md).

### Consequences

- Good: no lock table to pay for or secure, and the lock appears in the same bucket and versions as the state.
- Good: a wrong write can be undone by restoring a previous object version.
- Bad: requires Terraform 1.10 or later, so `required_version` is `>= 1.10.0`.
- Bad: the account root user can still change the bucket policy. This is intentional (it is the recovery path if the
  allow list is ever wrong), and root is protected with MFA and not used for daily work.

## More Information

- Terraform S3 backend, state locking: <https://developer.hashicorp.com/terraform/language/backend/s3#state-locking>
- Amazon S3 conditional writes: <https://docs.aws.amazon.com/AmazonS3/latest/userguide/conditional-requests.html>
