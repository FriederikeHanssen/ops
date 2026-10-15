# Local validation — 2026-10-15

These checks do not establish live AWS acceptance. No Terraform apply, AWS job, container pull, Platform CE registration, cutover or deletion was performed.

## Terraform

Terraform 1.14.5, signed official hashicorp/aws 6.69.0, macOS arm64:

```text
terraform fmt -check -recursive: passed
terraform validate: Success! The configuration is valid.
terraform test -no-color:
  explicit_names_and_gpu_backing: pass
  reject_null_workaround: pass
  reject_shared_fallback: pass
  reject_unavailable_queue: pass
  reject_invalid_backing_compute: pass
  reject_wrong_account: pass
Success! 6 passed, 0 failed.
```

All test runs specify `command = plan` and use a mock AWS provider. No live state/backend or AWS credentials were used. The positive plan verifies source compute associations, queue priority, job-state actions and the exact rendered routing expression; negative plans exercise the safety preconditions. They do not prove AWS availability, driver compatibility, permissions or repeated live plan stability.

## Nextflow

Nextflow 25.10.0, Java 17.0.13. GPU branch passed `-preview` using `process.executor = 'local'` from a temporary override config, the rendered routing expression, `--gpu true` and a synthetic image name. Preview ran no processes and pulled no image. This checks DSL/config syntax only.

The CPU probe then ran locally with the same synthetic routing expression, `--exercise_fallback true`, local executor override and `AWS_BATCH_JOB_ID=local-validation`. The local script printed `arm64`; that describes this Mac and does not establish AWS workload architecture. The synthetic queue pair deliberately uses GPU-labelled strings to check routing is driven by the supplied pair, independently of process names; this CPU test is not a GPU test.

The Nextflow trace recorded:

| Process   | Status    | Exit | Attempt | Configured queue                 |
| --------- | --------- | ---- | ------- | -------------------------------- |
| CPU_PROBE | FAILED    | 143  | 1       | nf-core-megatests-pilot-gpu-spot |
| CPU_PROBE | COMPLETED | 0    | 2       | gpu-ondemand                     |

This proves the closure selects the explicit first-attempt and retry strings in Nextflow. Local executor ignores those queue names for execution, so it does not prove AWS scheduling or Spot-to-On-Demand fallback. Live validation must use Batch `DescribeJobs.jobQueue` and GPU resource/driver evidence, following the README.

## Repository hooks

`prek run --files` passed Prettier and EditorConfig checks for the changed files. Python and Renovate hooks had no applicable files. Terraform-specific CI is added separately and runs format, init without backend, validate and mock plan tests; its GitHub result is recorded on the PR once available.
