## Summary
<!-- What this PR does and WHY, in 1–3 sentences. -->

Closes SIL-XXX <!-- use "Refs SIL-XXX" for partial work -->

## Changes
-

## How to test
1.

## Evidence
<!-- CI run link and the `terraform plan` summary (add / change / destroy per environment). Only real results. -->

## Security and operations impact
- [ ] Secrets / credentials: none added; providers authenticate through OIDC or environment variables
- [ ] IAM: new or changed permissions follow least privilege, or N/A
- [ ] Infra cost impact: none, or estimated monthly cost described below
- [ ] Destructive changes: no resource is destroyed or replaced, or the impact is described below
- [ ] Checkov / Trivy findings addressed or justified

## Documentation
<!-- docs/ pages, README, ADRs, or runbooks added/updated. "N/A" with a reason if none. -->

## Notes for the reviewer
<!-- Known limitations, follow-ups, where to start reading. -->

## Checklist
- [ ] Title follows Conventional Commits and ends with `[SIL-XXX]`
- [ ] `terraform fmt`, `validate`, and tflint pass, and CI is green
- [ ] `terraform plan` reviewed for every affected environment
- [ ] Code, comments, and docs in English
- [ ] Docs updated in this PR
