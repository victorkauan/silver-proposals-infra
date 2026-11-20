# OWASP Top 10:2025

How Silver Proposals addresses each category of the [OWASP Top 10:2025](https://top10.owasp.org/2025), comparing
**before the pipeline** (what could reach production with only manual review) with **after the pipeline** (the
design controls plus the automated checks that now run on every pull request). Last reviewed: 2026-11-19.

| Category | Before the pipeline | After the pipeline | Automated check |
|---|---|---|---|
| A01 Broken Access Control | An endpoint missing an ownership check would expose other users' proposals | Role check (owner, editor, viewer) on every proposal route, `404` for non-members, opaque share tokens; integration tests per role | pytest in `quality` (required) |
| A02 Security Misconfiguration | Console changes, public resources, and drift go unnoticed | All infrastructure in Terraform; plans on every pull request; private database; TLS everywhere; managed security headers on CloudFront | Checkov and Trivy (IaC) in `security`; plans in `plan` |
| A03 Software Supply Chain Failures | Vulnerable or malicious packages and mutable actions or images | Lockfiles; versions at least 14 days old; actions pinned by SHA; immutable ECR tags; image scan | pip-audit, npm audit (fails on high), Trivy image (fails on high), ECR scan on push |
| A04 Cryptographic Failures | Weak password storage or tokens in plain text | Argon2id; HS256 JWT with a 32+ byte secret from Secrets Manager; refresh and share tokens stored only as SHA-256 hashes; TLS 1.2+ and encryption at rest | Semgrep (`p/secrets`), Checkov (encryption checks) |
| A05 Injection | String-built SQL or unsafe HTML rendering | SQLAlchemy bound parameters; Pydantic validation on every input; React escaping; Markdown without raw HTML | Semgrep (`p/python`, `p/fastapi`, `p/typescript`, `p/react`), Bandit |
| A06 Insecure Design | Security decided late, per feature | Threat model, ADRs, and rate limits on login, sign-up, refresh, generation, and public links | Reviewed in pull requests (no tool) |
| A07 Authentication Failures | Credential stuffing, long-lived sessions | Rate-limited login and sign-up; 15-minute access tokens; rotating refresh tokens with reuse detection; `httpOnly`, `Secure`, `SameSite=Strict` cookie | pytest (auth tests) |
| A08 Software or Data Integrity Failures | Deploys from a laptop with static keys; unverified artifacts | GitHub OIDC (no static keys); the same image promoted from staging to prod; approvals for prod; optimistic locking (`409`) on content | Deploy workflows, environment rules |
| A09 Security Logging and Alerting Failures | No central logs; failures found by users | JSON logs with request IDs; traces; dashboards; 21 alarms by e-mail; budget alert | CloudWatch alarms (tested with a forced alarm) |
| A10 Mishandling of Exceptional Conditions | Stack traces or internal errors shown to clients; failing open | Central error handler with stable error codes and pt-BR messages; generation failures logged and reported to the client; `/ready` fails when the database is down | pytest (error paths), `api-down` alarm |

## Evidence from real runs

| Repository | Check | Result | Run |
|---|---|---|---|
| backend | Semgrep, Bandit, pip-audit, gitleaks | 0 findings (Semgrep 91 rules on 48 files), no known vulnerabilities, no leaks in 16 commits | [run 44439587341](https://github.com/victorkauan/silver-proposals-backend/actions/runs/44439587341/job/135276805818) |
| backend | Trivy image (HIGH) | 0 vulnerabilities (Debian 12.15 and Python packages) | [run 44439587341](https://github.com/victorkauan/silver-proposals-backend/actions/runs/44439587341/job/135276805412) |
| frontend | Semgrep, npm audit, gitleaks | 0 findings (60 rules on 103 files), 4 moderate (below the high gate), no leaks in 11 commits | [run 44373092227](https://github.com/victorkauan/silver-proposals-frontend/actions/runs/44373092227/job/135044896830) |
| infra | Checkov, Trivy (IaC), gitleaks | 377 passed, 0 failed, 53 skipped with reasons; Trivy clean; no leaks in 14 commits | [run 44437501302](https://github.com/victorkauan/silver-proposals-infra/actions/runs/44437501302/job/135269931426) |
| infra | Checkov blocking a pull request | 2 failed (CKV_AWS_358 on the deploy roles' OIDC trust policies), fixed before merge | [run 44366607648](https://github.com/victorkauan/silver-proposals-infra/actions/runs/44366607648/job/135021909502) |

Problems found outside the scanners and fixed in the same issue: share tokens in the Uvicorn access log and in
X-Ray trace URLs (found while verifying staging), and an unencrypted SNS topic flagged by Trivy before the push
(justified: CloudWatch alarms cannot publish to a topic encrypted with the AWS-managed key).

See also the [threat model](threat-model.md) and the [data processing record](data-processing.md).
