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
| Account | Name, e-mail, Argon2id password hash, accepted privacy notice version and time, timestamps | Sign-in, identifying the author of each version, and proof of the notice acceptance | Contract (V) | RDS `users`, us-east-1 | Until the user deletes the account (self-service) |
| Sessions | Refresh token SHA-256 hash, session family, expiry, use and revocation times | Keeping the user signed in; detecting stolen tokens | Contract (V); legitimate interest in security (IX) | RDS `refresh_tokens` | 7 days of validity; expired rows are deleted by the API every 6 hours |
| Proposals | Title, client name, briefing, content, versions with author and time | The service itself | Contract (V) | RDS `proposals`, `proposal_versions` | Until the owner deletes the proposal; deletion removes versions, members, and share links (cascade) |
| Generation | Briefing and instructions sent as the prompt; generated text | Writing the proposal draft | Contract (V) | Amazon Bedrock, US inference profile (us-east-1, us-east-2, us-west-2) | Not shared with the model provider and not used to train models; AWS may keep it for abuse detection depending on the model |
| Share links | Token SHA-256 hash, expiry, creator, revocation time | Read-only access for the user's client | Contract (V) | RDS `share_links` | Link valid 1–90 days; the row stays until the proposal is deleted |
| Application logs | Request ID, method, route template, status, duration, trace ID, event names, error codes | Operation, troubleshooting, security | Legitimate interest (IX) | CloudWatch Logs, us-east-1 | 14 days |
| Traces | Request URL (share tokens redacted), method, status, user agent, timings, SQL statements without values; client IP attributes are deleted by the collector before export | Performance and troubleshooting | Legitimate interest (IX) | AWS X-Ray, us-east-1 | 30 days (X-Ray fixed retention) |
| Network flow logs | Source and destination IPs and ports of VPC traffic | Security monitoring | Legitimate interest (IX) | CloudWatch Logs | 14 days |
| Backups | Full database snapshot | Recovery | Contract (V); legitimate interest (IX) | RDS automated backups | 1 day (AWS Free plan limit) |

The application never logs passwords, tokens, briefings, or proposal content, and logs contain the route template
instead of the raw path. Rate limiting uses the client IP in memory only, for at most one minute.

## Security measures (LGPD art. 46)

- **Encryption:** TLS on every hop (CloudFront TLS 1.2+, ALB TLS 1.3 policy, `rds.force_ssl`, AWS SDK over HTTPS);
  RDS storage, S3, ECR, and secrets encrypted at rest.
- **Access control:** owner, editor, and viewer roles on each proposal; non-members get `404`; the database is
  private and accepts only the API's security group; one database user per environment.
- **Credentials:** Argon2id for passwords; short-lived JWTs; rotating refresh tokens in `httpOnly` cookies; opaque,
  hashed share tokens; runtime secrets in AWS Secrets Manager; Bedrock through an IAM role, with no API keys.
- **Least privilege in the cloud:** CI uses GitHub OIDC with one role per environment under a permissions boundary;
  production changes need an approval.
- **Monitoring:** JSON logs, traces, dashboards, and alarms by e-mail. See [Monitoring](../reference/monitoring.md).

Details and threats: [Threat model](threat-model.md).

## International transfer (LGPD art. 33)

All data is stored and processed in the United States: the AWS us-east-1 Region and Bedrock's US inference profile.
At this stage the service runs with test data. A commercial launch must either back the transfer with one of the
mechanisms of art. 33, such as the standard contractual clauses of Resolução CD/ANPD nº 19/2024, or move the
workload to São Paulo (sa-east-1), which also needs a Bedrock model available there.

## Data subject rights (LGPD art. 18) and transparency

| Right or duty | How it is met |
|---|---|
| Access and portability | Minha conta → Privacidade e dados → Exportar meus dados (`GET /account/export`, JSON) |
| Correction | Minha conta → Perfil: name, and e-mail with the password |
| Deletion | Minha conta → Privacidade e dados → Excluir conta: deletes the account and sole-owned proposals; shared proposals keep the history without the author |
| Transparency (art. 9) | Public privacy notice at `/privacidade`; acceptance recorded at sign-up with version and time; users are asked again when the version changes |
| Data protection officer (art. 41) | privacidade@silversoft.com.br, published in the notice |

## Gaps

| Gap | LGPD reference | Plan |
|---|---|---|
| Access logs (IP, date, time) kept 14–30 days | Marco Civil da Internet (Lei 12.965/2014), art. 15: 6 months for application providers that are companies | Keep ALB access logs for 6 months in an encrypted, access-controlled bucket (SIL-241) |
| Data stored outside Brazil without a formal transfer mechanism | Art. 33 | Disclosed in the privacy notice; decision record and formal mechanism before a commercial launch (SIL-241) |
| No incident response plan for notifying the ANPD and users | Art. 48 | Runbook based on the existing alarms (SIL-241) |
| Backups kept only 1 day | Art. 46 (availability) | Daily database dump kept 7–30 days (SIL-241) |
