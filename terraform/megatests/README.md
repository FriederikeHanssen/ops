# CPU Fusion setup

First rollout of [#216](https://github.com/nf-core/ops/issues/216), including the minimum manual CE registration needed from #220. CPU x86 only, with Wave, Fusion v2, NVMe and **EC2 heads**. Test names and a test work prefix; existing production infrastructure stays outside these states. S3-only, GPU and ARM variants are deferred. Fusion Snapshots are explicitly disabled for this first ordinary Fusion setup.

## One action, persistent setup

`.github/workflows/megatests.yml` runs validation on pull requests. On merges affecting this setup, or a manual run from `main`, one deployment job:

1. Applies `forge/`: creates the Spot and On-Demand Forge CEs, each with min/max vCPUs 0/1000 and `c6id,m6id,r6id`, matching the live CPU requirements.
2. Waits for `AVAILABLE` and reads **actual** queues, head queue and IAM role values from the Platform API. It checks workspace, credentials, account, region and CPU Fusion settings. No Forge names are predicted.
3. Applies `runtime/`: creates the native AWS Spot queue referencing the Forge compute, a manual CPU Fusion CE using its output, and a test nf-canary Launchpad entry. The manual CE uses the Forge EC2 head queue. The On-Demand Forge CE supplies the existing fallback pattern's other queue.
4. Waits for the manual CE, then requires both refreshed Terraform plans to be empty.
5. Optionally runs nf-canary on the manual Spot CE and On-Demand Forge CE, waiting for completion and requiring both results to be `SUCCEEDED`. This tail is disabled until `MEGATESTS_RUN_CANARY=true`; enable it after the first successful setup.

This follows [nf-seqerakit-nightly](https://github.com/seqeralabs/nf-seqerakit-nightly/tree/00467c184a59611fbb4f323ab51eb9fffce6edb9), with relevant merges/manual dispatch instead of a schedule. It has no automatic teardown, deployment approval job or production reference cutover. Applies remain serialized so merges cannot race the same state. A canary failure leaves the CEs available for inspection.

`runtime` exposes a `deployment` output with Spot/On-Demand queue names and ARNs, Spot backing-compute ARNs, launchable CE names/IDs, workspace/work directory and the canary pipeline name. These are the handoff values for the remaining #220 work; generated IDs are not copied into source configuration.

The initial names are:

- `nf-core-test-cpu-fusion-spot-forge` and `nf-core-test-cpu-fusion-ondemand-forge` — Terraform owns these Platform definitions; Forge owns their Batch/IAM/network/launch-template resources.
- `nf-core-test-cpu-fusion-spot` — native AWS queue owned by `runtime/`, sharing the Spot Forge compute.
- `nf-core-test-cpu-fusion` — manual Platform CE, owned by `runtime/`.
- `nf-core-test-cpu-fusion-canary` — Launchpad entry, owned by `runtime/`.

No imports are needed for these fresh test names; the previous PR's alias queues were never applied. Never use these states to adopt production resources implicitly. Keep names and settings in Terraform; generated runtime inputs are ignored and refreshed on each deployment.

## Final bootstrap, after the code is ready

Backend/OIDC setup can be done last, before the first live action. Neither has been provisioned by this PR. In GitHub's `megatests-test` environment configure:

| Kind            | Name                       | Value                                                                                                 |
| --------------- | -------------------------- | ----------------------------------------------------------------------------------------------------- |
| Variable        | `MEGATESTS_WORKSPACE_ID`   | Existing workspace ID; live AWSmegatests was `59994744926013`                                         |
| Variable        | `MEGATESTS_CREDENTIALS_ID` | Existing AWS credential ID in that workspace; credential secrets remain in Platform                   |
| Variable        | `MEGATESTS_AWS_ACCOUNT_ID` | Expected account; live baseline was `728131696474`                                                    |
| Variable        | `MEGATESTS_STATE_BUCKET`   | Pre-created private, encrypted, versioned S3 state bucket                                             |
| Variable        | `MEGATESTS_STATE_REGION`   | Bucket region                                                                                         |
| Variable        | `MEGATESTS_STATE_PREFIX`   | Stable unique prefix, e.g. `nf-core/megatests-test`                                                   |
| Variable        | `MEGATESTS_AWS_ROLE_ARN`   | AWS role that GitHub assumes using OIDC                                                               |
| Secret          | `MEGATESTS_SEQERA_TOKEN`   | Platform token able to manage test CEs/pipelines and use the existing AWS credential                  |
| Variable, later | `MEGATESTS_RUN_CANARY`     | Leave unset initially; set `true` to append canary launches on every deployment                       |
| Secret, later   | `MEGATESTS_GITHUB_TOKEN`   | Read-only access to the private `seqeralabs/nf-seqerakit` repository, needed only for the canary tail |

IDs and ARNs are configuration, not passwords. The role ARN tells GitHub **which AWS role to assume**; no long-lived AWS access keys are needed. The Batch queue ARNs come from actual infrastructure and are used by AWS/API checks; Platform and Nextflow use the queue **names**. No one needs to copy generated Batch ARNs into GitHub secrets.

The OIDC role needs S3 read/write access for the two state keys (`PREFIX/forge.tfstate`, `PREFIX/runtime.tfstate`) and their `.tflock` files, Batch describe access and create/update/delete/tag permissions for the native test queue. Restrict its OIDC trust to this repository and the `megatests-test` environment, and restrict that environment to `main`. The existing AWS credential in Platform handles Forge provisioning and workflow launches; its permissions must cover both Forge resources and the new native queue. The action reports missing configuration before applying anything. It does not bootstrap its own state bucket or IAM role.

Two Terraform roots are used only for the creation-order boundary: the provider can return before asynchronous Forge provisioning is complete. The action waits and discovers the queue identifiers between applies. Both stages run in the same job, without `-target` or a manual handoff. Keep both state files; storing them only on a disposable runner would lose ownership on the next run.

## Deletion and rebuild

Forge disposal is enabled as agreed. Normally deleted Platform carriers are detected during Terraform refresh and recreated by rerunning the action. Discovery then exports their new identifiers and the runtime root reconciles the consumer. There is no `prevent_destroy` gate or preservation project for these test CEs. A partial failed Forge cleanup may leave AWS resources requiring repair; rerunning cannot guarantee recovery from every partially deleted AWS resource or an orphaned name collision. If destroying the whole setup later, destroy `runtime/` before `forge/` so the native queue does not obstruct Forge's backing-compute cleanup. No destroy is automatic.

The routing template preserves `task.attempt > 1`, `maxRetries=2`, the existing exit-code retry filter and `aws.batch.maxSpotAttempts=5`. Snapshots use the native field, not embedded Nextflow configuration. The root AGENTS note is interpreted in its legacy README context: avoid configuring snapshots inside `nextflowConfig`; ordinary queue/retry configuration already uses that field in the historical implementation. No retry-policy redesign is included.

## Checks and later acceptance

Local/PR checks require no AWS/Seqera credentials:

```sh
python3 -m unittest discover -s terraform/megatests/tests
terraform fmt -check -recursive terraform/megatests
for root in forge runtime; do
  terraform -chdir="terraform/megatests/$root" init -backend=false -lockfile=readonly
  terraform -chdir="terraform/megatests/$root" validate
  terraform -chdir="terraform/megatests/$root" test
 done
```

The nf-canary tail uses a pinned nf-seqerakit commit and nf-canary `0.2.0`, and separate output paths per action run and CE. It checks ordinary execution on both capacity paths. It does **not** prove the retry queue switch, real reclamation recovery or resume behavior. Add targeted fallback/resume checks after the basic setup works, as agreed. GPU and ARM remain later work.

Local checks passed with Terraform 1.14.5, AWS provider 6.69.0 and Seqera provider 0.42.0: both roots validate, all four mock plans pass, all ten Python tests pass, and repository hooks pass. These checks do not exercise cloud provisioning.

No live apply or canary launch has been performed here. Direct AWS IAM/network/AMI validation, provider normalization and repeat plan stability still need the first configured deployment. Bootstrap and the first spend-bearing run remain subject to the user's explicit authorization; this PR only prepares the executable workflow.
