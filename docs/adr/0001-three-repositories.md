---
status: accepted
date: 2026-11-16
decision-makers: Victor Kauan
---

# Split the project into backend, frontend, and infra repositories

## Context and Problem Statement

Silver Proposals has three parts with different toolchains, release cycles, and risk profiles: a Python API,
a TypeScript single-page app, and Terraform that manages the AWS account and DNS. How should the source code
be organized so that each part can be built, tested, secured, and deployed with the least coupling?

## Decision Drivers

- Least privilege in CI/CD. Only infrastructure pipelines may change cloud resources.
- Independent pipelines that run only the checks relevant to each stack.
- A clear integration contract between application delivery and infrastructure.
- Low operational overhead for a single maintainer.

## Considered Options

- Monorepo with backend, frontend, and infra
- Two repositories: application (backend + frontend) and infra
- Three repositories: backend, frontend, and infra

## Decision Outcome

Chosen option: **three repositories**. It is the only option where each pipeline and each GitHub OIDC role
is scoped to exactly one concern. App repositories can push artifacts and roll out releases, and only the
infra repository can create, change, or destroy infrastructure.

The repositories integrate as follows:

- **backend** builds a container image and pushes it to Amazon ECR, then rolls out the ECS service.
- **frontend** builds static assets and publishes them to Amazon S3 behind CloudFront.
- **infra** defines every AWS and Cloudflare resource. Its Terraform outputs become GitHub Actions
  variables of the backend and frontend repositories ([outputs contract](../reference/outputs-contract.md)).

### Consequences

- Good, because each OIDC trust policy is bound to a single repository, which limits the blast radius of a compromised workflow.
- Good, because CI runs only the relevant toolchain (pytest, Vitest, or Terraform scans), which keeps feedback fast.
- Good, because infrastructure changes get their own review flow (`plan` on pull requests, `apply` with approval).
- Bad, because a change that crosses repositories needs one pull request per repository, coordinated by the same issue.
- Bad, because Terraform outputs must be propagated to the app repositories. That step is documented in the outputs contract and must be kept in sync.

### Confirmation

- Each repository has its own CI workflow, and none of them contains code from another concern.
- The app repositories' deploy roles have no permission to manage infrastructure.

## Pros and Cons of the Options

### Monorepo

- Good, because cross-cutting changes land in a single pull request.
- Bad, because path-filtered workflows and a shared OIDC subject make least-privilege permissions harder to enforce.
- Bad, because every contributor and workflow can reach the infrastructure code.

### Two repositories (application + infra)

- Good, because infrastructure is isolated.
- Bad, because Python and Node.js toolchains share one pipeline and one release cycle.

### Three repositories

- Good, because of isolation, scoped permissions, and focused pipelines.
- Bad, because of coordination overhead across repositories.
