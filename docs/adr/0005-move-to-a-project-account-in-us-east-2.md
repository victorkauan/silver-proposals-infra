# ADR-0005 Move to a project account in us-east-2

## Context

The first AWS account was on the AWS Free plan, which ended on 2026-11-21. The account was suspended and its data,
including the Terraform state bucket and the frontend buckets, is out of reach unless the account moves to the
Paid plan. The project moves to a new Free plan account created through the new AWS sign-up experience, which
creates an organization with a management account and a *project account* for the workload.

AWS manages service control policies (SCPs) on project accounts. The project account was probed with
`iam simulate-principal-policy`, EC2 dry runs, and `sts decode-authorization-message` on 2026-11-22:

- In us-east-1, only global services are allowed (IAM, CloudFront, ACM, Bedrock, Budgets, billing, and the
  read actions of CloudWatch). EC2, RDS, ECS, ECR, S3, Secrets Manager, SNS, CloudWatch alarms, Scheduler,
  X-Ray, and SES are denied there, reads included (statement `UsEast1Partitional`).
- Every service the project uses is allowed in the project's region, **us-east-2**.
- Console passwords for IAM users are denied. People sign in with `aws login` through the AWS-managed role
  `managed/AccountFullAccessRole`, which issues temporary credentials.
- The Nova 2 Lite US inference profile (`us.amazon.nova-2-lite-v1:0`) is active in us-east-2, but every Nova quota
  (requests and tokens per minute, tokens per day) is 0 there, so calls fail with `ThrottlingException`. In us-east-1
  the same quotas are normal (2,000 requests and 8 million tokens per minute).

## Decision

- Run every regional resource in **us-east-2**. The only exception is the CloudFront certificates, which
  CloudFront requires in us-east-1 (ACM is allowed there). The certificate module takes a per-resource `region`.
- The API calls Bedrock in **us-east-1** (`bedrock_region`), through the same US inference profile. Only the
  Bedrock runtime endpoint changes region; the prompts already crossed US regions through the profile.
- The operators are the role `managed/AccountFullAccessRole`, not an IAM user. The state, backup, and ALB log
  bucket policies name this role. There are still no access keys anywhere.
- Rename the buckets whose global names still belong to the suspended account: the state bucket becomes
  `silversoft-silver-proposals-tfstate-v2` and the frontend buckets get a `-v2` suffix.
- Drop the CloudFront 5xx alarm. CloudFront publishes its metrics only in us-east-1, where alarms are denied.
  The dashboard keeps a chart of the app's requests and 5xx rate, read from us-east-1.
- Start with empty databases and new secrets. The old data cannot be read while the old account is suspended.

This amends [ADR-0004](0004-keep-the-us-region-for-the-academic-deployment.md): the data stays in the United
States, so the transfer analysis is unchanged, but the region is now us-east-2.

## Consequences

- The application code does not change. Region values come from Terraform and the GitHub `AWS_REGION` variable.
- Users of the first account must sign up again, and authenticator apps must be enrolled again.
- A failing frontend is not alarmed. API alarms still cover the backend, and the dashboard shows the app's errors.
- If the account is upgraded to the Paid plan, review whether the AWS-managed policies still apply before
  moving anything back to us-east-1.

## References

- [SCPs and RCPs for projects](https://docs.aws.amazon.com/accounts/latest/reference/scps-and-rcps-for-projects.html)
- [Activate advanced AWS features](https://docs.aws.amazon.com/accounts/latest/reference/activate-advanced-features.html)
- [CloudFront: certificates must be in us-east-1](https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/cnames-and-https-requirements.html)
