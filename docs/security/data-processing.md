# Data processing record (LGPD)

What personal data Silver Proposals processes, why, where, for how long, and what is still missing to meet the
LGPD (Lei 13.709/2018) for a commercial launch. This is an engineering record, not legal advice. Last reviewed:
2026-11-20.

## Roles

- **Controller** of account data and of the technical records (logs, traces): the operator of Silver Proposals.
- **Proposal content** (briefings and generated text) can contain personal data of the user's own clients, such as
  contact names. For that data, the user's company is the controller and Silver Proposals acts as the **operator**
  (processor), processing it only to generate and store the proposal.
- **Sub-processors:** Amazon Web Services (hosting, database, logs, traces, and Amazon Bedrock for generation).
  Cloudflare provides DNS only and does not receive application traffic. GitHub hosts code and CI and receives
  no user data.

## Processing activities

| Activity | Data | Purpose | Legal basis (LGPD art. 7) | Where | Retention |
|---|---|---|---|---|---|
| Account | Name, e-mail, Argon2id password hash, accepted privacy notice version and time, timestamps | Sign-in, identifying the author of each version, and proof of the notice acceptance | Contract (V) | RDS `users`, us-east-2 | Until the user deletes the account (self-service) |
| Sessions | Refresh token SHA-256 hash, session family and start, browser (`User-Agent`, up to 255 characters), expiry, use and revocation times | Keeping the user signed in; detecting stolen tokens; letting the user see and end sessions | Contract (V); legitimate interest in security (IX) | RDS `refresh_tokens` | 7 days of validity; expired rows are deleted by the API every 6 hours |
| Two-factor authentication | TOTP secret (AES-256-GCM), last accepted code step, recovery code hashes (HMAC-SHA256), enable time | Protecting the account against a leaked password | Contract (V); legitimate interest in security (IX) | RDS `users`, `recovery_codes` | Until the user turns 2FA off or deletes the account |
| Proposals | Title, client name, briefing, content, versions with author and time | The service itself | Contract (V) | RDS `proposals`, `proposal_versions` | Until the owner deletes the proposal; deletion removes versions, members, and share links (cascade) |
| Generation | Briefing and instructions sent as the prompt; generated text | Writing the proposal draft | Contract (V) | Amazon Bedrock, US inference profile (us-east-1, us-east-2, us-west-2) | Not shared with the model provider and not used to train models; AWS may keep it for abuse detection depending on the model |
| Share links | Token SHA-256 hash, expiry, creator, revocation time | Read-only access for the user's client | Contract (V) | RDS `share_links` | Link valid 1–90 days; the row stays until the proposal is deleted |
| Application logs | Request ID, method, route template, status, duration, trace ID, event names, error codes | Operation, troubleshooting, security | Legitimate interest (IX) | CloudWatch Logs, us-east-2 | 14 days |
| Traces | Request URL (share tokens redacted), method, status, user agent, timings, SQL statements without values; client IP attributes are deleted by the collector before export | Performance and troubleshooting | Legitimate interest (IX) | AWS X-Ray, us-east-2 | 30 days (X-Ray fixed retention) |
| Network flow logs | Source and destination IPs and ports of VPC traffic | Security monitoring | Legitimate interest (IX) | CloudWatch Logs | 14 days |
| ALB access logs | IP, request time and line, status and delivery details | Security and access records | Legal obligation where applicable (II); legitimate interest (IX) | Restricted S3 archive, us-east-2 | 184 days |
| Backups | Full database snapshot and daily logical dump, including account and proposal data | Recovery | Contract (V); legitimate interest (IX) | RDS automated backups and restricted S3 archives, us-east-2 | 1 day for RDS snapshots; 14 days for scheduled logical dumps |

The application logs route templates. The load balancer records raw request URLs when delivery is enabled. The web app resolves public shares through a fixed API path with the token in the POST body. The deprecated direct GET route can still put a token in a load balancer record. WAF publishes aggregate counters, and application rate limiting keeps IPs in memory.

## Security measures (LGPD art. 46)

- **Encryption:** HTTPS from browsers to CloudFront and the ALB, TLS to RDS and AWS service APIs, and encryption at rest in RDS, S3, ECR and Secrets Manager. The ALB forwards to API tasks over HTTP inside the VPC, limited by their security groups.
- **Access control:** owner, editor, and viewer roles on each proposal; non-members get `404`; the database is
  private and accepts only the API's security group; one database user per environment.
- **Credentials:** Argon2id for passwords; optional TOTP two-factor authentication with encrypted secrets and hashed
  recovery codes; sessions the user can list and end; short-lived JWTs; rotating refresh tokens in `httpOnly` cookies; opaque,
  hashed share tokens; runtime secrets in AWS Secrets Manager; Bedrock through an IAM role, with no API keys.
- **Least privilege in the cloud:** CI uses GitHub OIDC with one role per environment under a permissions boundary;
  production changes need an approval.
- **Monitoring:** JSON logs, traces, dashboards, and alarms by e-mail. See [Monitoring](../reference/monitoring.md).

See [Threat model](threat-model.md), [Security hardening rollout](../runbooks/security-hardening.md), and [Incident response](../runbooks/security-incident.md).

## International transfer (LGPD art. 33)

The academic deployment uses US hosting and a US Bedrock inference profile. ADR-0004 records the regional decision and the contractual verification required before commercial launch. [ADR-0004](../adr/0004-keep-the-us-region-for-the-academic-deployment.md).

## Data subject rights (LGPD art. 18) and transparency

| Right or duty | How it is met |
|---|---|
| Access and portability | Minha conta → Privacidade e dados → Exportar meus dados (`GET /account/export`, JSON) |
| Correction | Minha conta → Perfil: name, and e-mail with the password |
| Deletion | Minha conta → Privacidade e dados → Excluir conta: deletes the account and sole-owned proposals; shared proposals keep the history without the author |
| Transparency (art. 9) | Public privacy notice at `/privacidade`; acceptance recorded at sign-up with version and time; users are asked again when the version changes |
| Data protection officer (art. 41) | privacidade@silversoft.com.br, published in the notice |

## Remaining obligations

- ALB access logging is enabled and verified, with 184-day retention for the API ALB. Evaluate access-record obligations for all application entry points (static CloudFront requests are outside this log) before commercial launch. [Marco Civil da Internet art. 15](https://www.planalto.gov.br/ccivil_03/_ato2011-2014/2014/lei/l12965.htm), [Decreto 8.771/2016](https://planalto.gov.br/ccivil_03/_ato2015-2018/2016/decreto/d8771.htm).
- Scheduled uploads and a staging restore were verified. Copies of deleted records may remain in encrypted backups until expiration (at most 14 days). [Restore runbook](../runbooks/database-restore.md).
- Confirm the applicable international transfer mechanism before commercial launch. [ADR-0004](../adr/0004-keep-the-us-region-for-the-academic-deployment.md).
