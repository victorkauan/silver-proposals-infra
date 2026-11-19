# Threat model

A short threat model of Silver Proposals v1: what we protect, where the trust boundaries are, the threats that
matter (STRIDE), and how each one is mitigated. Every mitigation points to where it lives, so it can be checked.

Scope: the web app, the API, the database, the Bedrock integration, and the CI/CD pipelines in the three
repositories ([backend](https://github.com/victorkauan/silver-proposals-backend),
[frontend](https://github.com/victorkauan/silver-proposals-frontend), and this one). Last reviewed: 2026-11-19.

## System and trust boundaries

```text
 Browser (user)          Browser (anyone with a share link)
      │ HTTPS                        │ HTTPS
      ▼                              ▼
 CloudFront + S3 (static app)   ──────────────── [B1: internet → AWS edge]
      │ HTTPS (TLS 1.2+)
      ▼
 ALB (shared) ── HTTPS only, TLS 1.3 policy ──── [B2: edge → VPC]
      │ HTTP inside the VPC, security group: ALB only
      ▼
 ECS Fargate task: API container + OTel collector sidecar
      │ TLS (rds.force_ssl)             │ IAM task role (SigV4)
      ▼                                 ▼
 RDS PostgreSQL 17 (private)      Amazon Bedrock (Nova 2 Lite, US profile) ── [B3: our account → AWS service]

 GitHub Actions ── OIDC, short-lived roles ──── [B4: CI → AWS account]
```

## Assets

| Asset | Where | Why it matters |
|---|---|---|
| User accounts (name, e-mail, password hash) | RDS `users` | Account takeover, personal data (LGPD) |
| Proposal content and briefings | RDS `proposals`, `proposal_versions` | Commercial secrets of the user's clients |
| Sessions (access JWT, refresh tokens) | Browser memory / `httpOnly` cookie; RDS stores refresh token hashes | Impersonation |
| Share tokens | Only in the link given to the user; RDS stores the SHA-256 hash | Read access to a proposal without an account |
| Secrets (JWT key, database credentials) | AWS Secrets Manager | Full compromise of the API or database |
| AWS account and pipelines | IAM, GitHub environments | Control of all of the above |

## Threats and mitigations

| # | STRIDE | Threat | Mitigation | Where |
|---|---|---|---|---|
| T1 | Spoofing | Password guessing or credential stuffing on login | Argon2id hashes; login limited to 5/min and sign-up to 3/min per IP; same error for unknown e-mail and wrong password | backend `features/auth` |
| T2 | Spoofing | Stolen session | Access token lives 15 min in memory only; refresh token in a `Secure`, `httpOnly`, `SameSite=Strict` cookie, rotated on every use; reusing a rotated token revokes the whole session family | backend `features/auth/service.py` |
| T3 | Elevation of privilege | User reads or edits another user's proposal (IDOR) | Every proposal route checks membership and role (owner, editor, viewer); non-members get `404`, so IDs reveal nothing | backend `features/proposals/service.py` |
| T4 | Information disclosure | Guessing or leaking share links | 32 random bytes per token; only the hash is stored; links expire (1–90 days) and can be revoked; public reads limited to 60/min; one `404` for every invalid link; tokens kept out of logs (route template, no access log) and out of traces (redacted span URLs) | backend `features/sharing`, `shared/observability.py` |
| T5 | Tampering | SQL injection | SQLAlchemy with bound parameters only; Semgrep (`p/python`, `p/fastapi`) and Bandit in CI | backend CI `security` |
| T6 | Tampering | XSS through generated or edited Markdown | React escapes text; Markdown is rendered with `react-markdown` without raw HTML; Semgrep `p/react` in CI; CloudFront adds the managed security headers policy | frontend, `modules/frontend` |
| T7 | Information disclosure | Database exposed to the internet | RDS is not publicly accessible; its security group accepts only the API tasks; TLS forced (`rds.force_ssl`); storage encrypted; one database and user per environment with `PUBLIC` revoked | `modules/database`, `modules/api_service/scripts` |
| T8 | Information disclosure | Leaked secrets in code or images | No secrets in git (gitleaks over the full history in every repo); runtime secrets come from Secrets Manager; Bedrock is called with the task role, so there are no AI keys; CI uses OIDC, so there are no static AWS keys | all CI, `modules/api_service` |
| T9 | Tampering | Supply chain: malicious or vulnerable dependency | Lockfiles; new versions at least 14 days old; pip-audit, npm audit (fails on high), Trivy on the image (fails on high); actions pinned by SHA; ECR tags immutable with scan on push | all CI, `modules/ecr` |
| T10 | Elevation of privilege | Compromised CI job takes over the AWS account | OIDC roles trust one repository and one environment each; a permissions boundary caps every workload role; `prod` and `shared` need an approval in GitHub | `bootstrap/github-oidc.tf`, `.github/workflows/deploy.yml` |
| T11 | Denial of service | Cost or capacity abuse of AI generation | Generation limited to 10/min per IP and 4096 output tokens; US$ 40 budget alert; CloudWatch alarms on failures, latency, CPU, and memory | backend `features/generation`, `environments/shared`, `modules/monitoring` |
| T12 | Repudiation | No trace of who changed what | Every version records its author; JSON request logs with request ID; CloudTrail event history for AWS changes | backend `features/versions`, `modules/monitoring` |
| T13 | Information disclosure | Prompt data sent to a third party | Bedrock runs inside AWS: prompts are not shared with the model provider or used to train models, and the `us.` inference profile keeps processing in US Regions | [Data processing record](data-processing.md) |
| T14 | Tampering | Infrastructure misconfiguration | Checkov and Trivy (IaC) in CI; plans posted on every pull request; applies only through the pipeline | CI `security`, `plan` |

## Residual risks (accepted in v1)

| Risk | Why accepted now | What would fix it |
|---|---|---|
| No WAF on CloudFront or the ALB | Cost; per-route rate limits cover the abuse cases we know | AWS WAF with managed rules and a rate-based rule |
| Rate limits live in each task's memory | v1 runs one task per environment | A shared store (for example ElastiCache) when scaling out |
| No multi-factor authentication for app users | Not in v1 scope | TOTP or passkeys |
| The ECS execution role can read the RDS master secret | The database-setup task shares it with the API service | A separate execution role for the setup task |
| The JWT key and database password are in the Terraform state | Generated by Terraform | The state bucket is encrypted and readable only by the operator and the CI roles; move generation to Secrets Manager rotation |
| 4 moderate `npm audit` findings (`minimatch` ReDoS through the `shadcn` CLI) | Build-time tool, not shipped to browsers; the gate fails only on high | Move `shadcn` to `devDependencies` or update when a fix ships |
| RDS backups kept 1 day | AWS Free plan limit | 7 or more days on a paid plan |
| Bedrock may keep prompts for abuse detection, depending on the model | AWS default for the model; nothing is shared with the provider | Set the account's data retention mode to `none` where the model allows it |

See also the [data processing record](data-processing.md) and the [OWASP Top 10 table](owasp-top-10.md).
