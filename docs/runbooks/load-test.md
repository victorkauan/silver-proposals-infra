# Load test of the generation endpoint

The [k6 script](../../tests/load/generation.js) measures how many simultaneous generations one API task handles.
Each virtual user keeps one generation in flight and starts at most one per minute, because the API allows
10 generations per minute per client IP. More load comes from more source IPs: the manual
[Load test workflow](../../.github/workflows/load-test.yml) runs the script on several GitHub-hosted runners at once.

## Target

One API task keeps **20 simultaneous generations** with the 95th percentile of the time to the first byte under 5 s
and fewer than 1% failed generations. The script's thresholds encode both limits.

## What each runner does

1. `setup()` registers a throwaway user and creates one proposal per virtual user.
2. All runners start the load at the same moment (five minutes after the workflow starts), so their generations overlap.
3. Each virtual user generates its proposal, then waits for the rest of its minute. A generation counts as successful
   only when the stream ends with `event: done`; failures are counted by error code.
4. `teardown()` deletes the user and its proposals.

## Run

1. Make sure the environment is up (`scripts/environment-power.sh status`).
2. Actions → **Load test** → Run workflow. `runners` × `vus` is the number of generations in flight, for example
   2 × 10 = 20 for the target and 6 × 10 = 60 to find the limit. `host_ip` sends the API host name to a given load
   balancer IP without changing DNS; TLS still uses the host name.
3. Each runner uploads `summary-<n>.json`. Read `generation_success`, `generation_first_byte`, and `generation_duration`.

Locally, with a smaller load:

```bash
BASE_URL=https://api-staging.silversoft.com.br VUS=2 DURATION=30s PACE_SECONDS=20 k6 run tests/load/generation.js
```

## Cost and care

- Every generation is a real model call; 60 generations per minute for three minutes is about 180 calls.
- WAF allows 1,000 requests per 5 minutes per IP, well above what one runner sends.
- Run it against staging only, and pause the environment afterwards if it is not otherwise needed
  ([Pause and resume](pause-and-resume.md)).
