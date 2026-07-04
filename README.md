# nf-resume-test

A deliberately late-failing Nextflow DSL2 pipeline used to validate the
nextflow-gcp-platform control-plane's **FAIL -> RESUME** path at real
google-batch scale (dev project `nextflow-test-499820`).

- `UPSTREAM` sleeps ~30s, emits a file, succeeds (and is cached).
- `GATE` consumes it and passes only if a GCS sentinel object exists, else
  `exit 1`.

Toggle is a GCS object (`params.gate_sentinel`, default
`gs://nextflow-test-499820-nf-work/nf-resume-test/gate-pass`), NOT a Nextflow
param, because the control plane's resume reuses the original run's params
verbatim.

First run (no sentinel): GATE fails -> run FAILED. Create the sentinel, then
`POST /runs/{id}/resume`: UPSTREAM is `Cached`, GATE re-runs and succeeds.
