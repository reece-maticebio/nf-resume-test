#!/usr/bin/env nextflow
/*
 * nf-resume-test — a deliberately-late-failing DSL2 pipeline to prove the
 * control-plane's FAIL->RESUME path reuses cached upstream work at real
 * google-batch scale.
 *
 *   UPSTREAM  sleeps briefly, emits a file -> SUCCEEDS (and is cached).
 *   GATE      consumes UPSTREAM's file; PASSES only if a GCS sentinel exists,
 *             else `exit 1`. The sentinel check is the SAME script text every
 *             run, so GATE's task hash is stable and UPSTREAM's hash is
 *             unaffected by the toggle. First run (no sentinel) -> GATE FAILS
 *             -> run FAILED. Create the sentinel, then resume -> UPSTREAM is
 *             Cached (reused), GATE re-runs and SUCCEEDS -> run SUCCEEDS.
 *
 * The toggle is a GCS object (NOT a Nextflow param) on purpose: the control
 * plane's POST /runs/{id}/resume reuses the original run's params verbatim, so
 * a param toggle could not be flipped between attempts.
 */

nextflow.enable.dsl2 = true

// Fixed sentinel path (identical on the original run and its resume, so GATE's
// hash never changes). Overridable but the control plane passes no params here.
params.gate_sentinel = 'gs://nextflow-test-499820-nf-work/nf-resume-test/gate-pass'

process UPSTREAM {
    container 'google/cloud-sdk:slim'

    output:
    path 'upstream.txt'

    script:
    """
    sleep 30
    echo "upstream-produced-ok" > upstream.txt
    """
}

process GATE {
    container 'google/cloud-sdk:slim'

    input:
    path upstream_file

    output:
    path 'gate.txt'

    script:
    """
    cat ${upstream_file}
    if gsutil -q stat ${params.gate_sentinel}; then
        echo "gate-passed: sentinel present" > gate.txt
    else
        echo "gate sentinel ${params.gate_sentinel} missing -> failing (exit 1)" >&2
        exit 1
    fi
    """
}

workflow {
    UPSTREAM()
    GATE(UPSTREAM.out)
}
