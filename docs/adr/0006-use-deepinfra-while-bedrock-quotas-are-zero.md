# ADR-0006 Use DeepInfra while the Bedrock quotas are zero

## Context

In the project account ([ADR-0005](0005-move-to-a-project-account-in-us-east-2.md)), every Amazon Nova quota on
Bedrock is 0 in us-east-1 and us-east-2, including "Model invocation max tokens per day", which is not adjustable
in Service Quotas. us-west-2 has the default per-minute quotas, but its daily token quota is also 0, so every
generation fails with `ThrottlingException`. A quota increase was requested from AWS Support on 2026-11-22.

## Decision

- Staging and production set `ai_provider = "deepinfra"`. The API calls DeepInfra's OpenAI-compatible API with
  `zai-org/GLM-5.3-Flash` (`deepinfra_model_id`). The backend repository records why this model was chosen.
- The API key lives in a Secrets Manager secret per environment (`silver-proposals-<environment>/deepinfra`).
  Terraform creates the secret without a value; an operator sets it by hand, so the key never enters Terraform state,
  the repository, or CI. The execution role may read it, and the task receives it as `DEEPINFRA_API_KEY`.
- The Bedrock configuration and IAM permissions stay. Going back is `ai_provider = "bedrock"` once AWS raises the
  quotas.

## Consequences

- Generation works without waiting for AWS Support.
- Briefings go to a provider outside AWS. DeepInfra states that inference inputs and outputs stay in memory, are not
  logged, and are not used for training; the privacy notice and the [data processing record](../security/data-processing.md)
  name it while it is active.
- There is now a third-party API key to protect and replace by hand if it leaks.
- Each environment's secret adds about US$ 0.40 per month.

## References

- [DeepInfra data privacy](https://docs.deepinfra.com/account/data-privacy)
- [DeepInfra privacy policy](https://deepinfra.com/privacy)
- [Amazon Bedrock quotas](https://docs.aws.amazon.com/bedrock/latest/userguide/quotas.html)
