# ADR-0004 Keep the US region for the academic deployment

## Context

RDS, ECS, the ALB and the operational archives run in us-east-1. The Nova 2 Lite US inference profile can route text processing to more than one US region. Account records and proposal content can contain Brazilian personal data. The processing purpose and legal basis are documented in the [data processing record](../security/data-processing.md). International transfer is a separate obligation under LGPD art. 33.

## Decision

Keep us-east-1 and the current US inference profile for the academic deployment with test data. This preserves the tested service configuration and model behavior. Reassess São Paulo for commercial use. Hosting application data in São Paulo would reduce the scope of foreign hosting, while inference and any other processing outside Brazil would still require review. Moving the workload requires verifying service and model availability, residency and cost.

Publish the actual region and inference geography in the privacy notice. Before processing real customers' personal data at commercial launch, verify an applicable art. 33 mechanism for the actual parties and transfer paths. ANPD standard contractual clauses are the intended mechanism if applicable. Verify incorporation into the contracts, transfer scope, provider terms and responsibilities. Record the reviewed mechanism and its evidence before opening the service to customers. [Resolução CD/ANPD 19/2024](https://www.gov.br/anpd/pt-br/acesso-a-informacao/institucional/atos-normativos/regulamentacoes_anpd/resolucao-cd-anpd-no-19-de-23-de-agosto-de-2024), [AWS and LGPD](https://aws.amazon.com/compliance/brazil-data-privacy/).
