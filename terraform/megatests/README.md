# CPU Fusion setup

First setup for [#216](https://github.com/nf-core/ops/issues/216), including the manual CE registration needed from #220. Creates exactly three test CEs:

1. `nf-core-test-cpu-fusion-spot-forge` — Forge Spot infrastructure.
2. `nf-core-test-cpu-fusion-ondemand-forge` — Forge On-Demand infrastructure.
3. `nf-core-test-cpu-fusion` — manual CE using the actual Spot and On-Demand queues, plus the Forge EC2 head queue and role.

CPU x86 only: Wave, Fusion v2, NVMe, EC2 heads, min/max vCPUs 0/1000. Both Forge CEs use the explicit [Seqera snapshot-compatible instance sizes](https://docs.seqera.io/fusion/guide/snapshots/aws#selecting-an-ec2-instance):

```text
c6id.4xlarge,c6id.8xlarge,c6id.12xlarge,m6id.4xlarge,m6id.8xlarge,r6id.2xlarge
```

Unrestricted family names would also permit sizes outside that recommendation. Seqera cautions that `m6id.8xlarge` may miss the snapshot window when using most of its 128 GiB memory; validate checkpoint timing before relying on snapshots for such tasks. Seqera Cloud supplies the ECS-optimized AMI by default, so no region-specific AMI ID is pinned here.

Fusion Snapshots use the native `fusion_snapshots` setting: enabled on the Spot Forge CE and the manual launch CE, disabled on the On-Demand Forge CE. The [manual CE setup guide](https://docs.seqera.io/platform-cloud/compute-envs/aws-batch#seqera-manual-compute-environment) includes the Snapshot toggle; the pinned provider requires Fusion to be enabled and permits this manual configuration. Snapshot/restore behavior on Spot and fallback still needs a live test. Existing production CEs stay outside this setup. S3-only, GPU, ARM and nf-canary are deferred.

## Workflow

`.github/workflows/megatests.yml` validates pull requests. Relevant merges or a manual dispatch from `main` run one deployment job:

```text
apply forge/ (Spot + On-Demand CEs)
→ wait for AVAILABLE and read actual queues/head/role
→ apply runtime/ (manual CE with explicit queue selection)
→ wait for the manual CE and check both plans are empty
```

The pinned Seqera provider creates a CE and immediately describes it; it does not wait for Forge to finish. That is why the workflow keeps two Terraform stages with a small discovery step between them. Both stages run in one job, with serialized applies and no approval stages or automatic teardown. The two state keys preserve ownership between action runs.

There is no duplicate AWS queue, AWS infrastructure provider, Launchpad resource, private pipeline checkout or canary scaffolding. Forge owns the backing AWS resources. `runtime` outputs the launchable CE names/IDs and the two actual queue names for consumers; generated identifiers are never guessed from CE IDs.

## Final bootstrap

Configure backend/OIDC last, before the first live run. In GitHub's `megatests-test` environment set:

| Kind     | Name                       | Purpose                                                                        |
| -------- | -------------------------- | ------------------------------------------------------------------------------ |
| Variable | `MEGATESTS_WORKSPACE_ID`   | Existing workspace ID; AWSmegatests was `59994744926013` on inspection         |
| Variable | `MEGATESTS_CREDENTIALS_ID` | Existing AWS credential ID in Platform; its secret remains in Platform         |
| Variable | `MEGATESTS_STATE_BUCKET`   | Private, encrypted, versioned S3 state bucket                                  |
| Variable | `MEGATESTS_STATE_REGION`   | Bucket region                                                                  |
| Variable | `MEGATESTS_STATE_PREFIX`   | Stable unique prefix, e.g. `nf-core/megatests-test`                            |
| Variable | `MEGATESTS_AWS_ROLE_ARN`   | OIDC role for reading/writing Terraform state                                  |
| Secret   | `MEGATESTS_SEQERA_TOKEN`   | Platform token able to manage the test CEs and use the existing AWS credential |

The AWS role needs S3 access to `PREFIX/forge.tfstate`, `PREFIX/runtime.tfstate` and their `.tflock` files. It does not need Batch queue-management permissions. Restrict OIDC trust to this repository/environment and the environment to `main`. The existing Platform AWS credential handles Forge infrastructure and launches. No AWS account-ID variable, Batch ARN configuration or private-repository token is needed. The action checks required configuration before applying anything; it does not create its own backend or OIDC role.

## Lifecycle and validation

Forge disposal is enabled as agreed. Rerunning the action recreates normally deleted test CEs, discovers their new queue names and reconciles the manual consumer. Partial failed Forge cleanup may still need repair. For a full cleanup, destroy `runtime/` before `forge/`. Fresh test names need no imports; no live resources from earlier PR revisions were applied.

The queue template preserves the existing `task.attempt > 1` boundary, `maxRetries=2`, exit-code retry filter and `aws.batch.maxSpotAttempts=5`. Snapshot settings use the native field, following the historical README guidance; ordinary queue/retry settings use a separate Nextflow template. No retry-policy redesign is included.

Local checks use no cloud credentials:

```sh
python3 -m unittest discover -s terraform/megatests/tests
terraform fmt -check -recursive terraform/megatests
for root in forge runtime; do
  terraform -chdir="terraform/megatests/$root" init -backend=false -lockfile=readonly
  terraform -chdir="terraform/megatests/$root" validate
  terraform -chdir="terraform/megatests/$root" test
done
```

After the setup works, add nf-canary to the workflow using the [nightly repository's launch pattern](https://github.com/seqeralabs/nf-seqerakit-nightly/tree/00467c184a59611fbb4f323ab51eb9fffce6edb9). Ordinary canary runs do not prove retry fallback or resume behavior; those checks follow separately. No live apply or spend-bearing test has been performed. Bootstrap, provider normalization, empty live plans and CPU/Fusion execution remain unverified until the first authorized deployment.
