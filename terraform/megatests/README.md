# AWS megatests setup

Setup for [#216](https://github.com/nf-core/ops/issues/216), including the manual CE registration needed from #220. Each workload uses the same two-stage setup and creates exactly three test CEs. The default CPU Fusion workload creates:

1. `nf-core-test-cpu-fusion-spot-forge` — Forge Spot infrastructure.
2. `nf-core-test-cpu-fusion-ondemand-forge` — Forge On-Demand infrastructure.
3. `nf-core-test-cpu-fusion` — manual CE using the actual Spot and On-Demand queues, plus the Forge EC2 head queue and role.

Select `workload` in the Forge root; discovery carries that selection into the manual CE automatically. Every workload has matching Spot and On-Demand capacity and EC2 head jobs. The default names and work prefixes are independent:

| Workload               | Manual launch CE          | Compute                                           | Storage                          | Max vCPUs | Snapshots        |
| ---------------------- | ------------------------- | ------------------------------------------------- | -------------------------------- | --------- | ---------------- |
| `cpu-fusion` (default) | `nf-core-test-cpu-fusion` | x86 CPU, sizes below                              | Fusion + NVMe                    | 1000      | Spot + manual CE |
| `cpu-s3`               | `nf-core-test-cpu-s3`     | `c6i`, `m6i`, `r6i`                               | S3 staging, Fusion/NVMe disabled | 1000      | Off              |
| `gpu-fusion`           | `nf-core-test-gpu-fusion` | `g4dn`, `g5`, `c6id`, `m6id`, `r6id`; GPU enabled | Fusion + NVMe                    | 500       | Off              |

Carrier names append `-spot-forge` and `-ondemand-forge`. Work directories default to `s3://nf-core-awsmegatests/test/<workload>`. Wave is enabled for all three. GPU families and the 500-vCPU limit preserve the historical GPU specification; the On-Demand pool has the same families and GPU flag as Spot. Pipelines must request GPUs with their `accelerator` directive; this CE does not force every CPU preprocessing task to request a GPU. GPU snapshots stay off because [Seqera requires a single GPU instance type and a compatible CUDA container for restore](https://docs.seqera.io/fusion/guide/snapshots#hardware-compatibility), whereas this pool preserves the historical mixed families.

Non-Fusion S3 staging consumes the actual AWS CLI path returned by Forge. Discovery requires both backing environments to report the same path before creating the manual CE, so staging and fallback do not depend on a guessed CLI installation location.

CPU Fusion uses the explicit [Seqera snapshot-compatible instance sizes](https://docs.seqera.io/fusion/guide/snapshots/aws#selecting-an-ec2-instance):

```text
c6id.4xlarge,c6id.8xlarge,c6id.12xlarge,m6id.4xlarge,m6id.8xlarge,r6id.2xlarge
```

Unrestricted family names would also permit sizes outside that recommendation. Seqera cautions that `m6id.8xlarge` may miss the snapshot window when using most of its 128 GiB memory; validate checkpoint timing before relying on snapshots for such tasks. Seqera Cloud supplies the ECS-optimized AMI by default, so no region-specific AMI ID is pinned here.

For `cpu-fusion`, Fusion Snapshots use the native `fusion_snapshots` setting: enabled on the Spot Forge CE and the manual launch CE, disabled on the On-Demand Forge CE. The [manual CE setup guide](https://docs.seqera.io/platform-cloud/compute-envs/aws-batch#seqera-manual-compute-environment) includes the Snapshot toggle; the pinned provider requires Fusion to be enabled and permits this manual configuration. Snapshot/restore behavior on Spot and fallback still needs a live test. Existing production CEs stay outside this setup. ARM deployment is deferred by agreement: provider 0.42.0's [Graviton validator](https://github.com/seqeralabs/terraform-provider-seqera/blob/v0.42.0/internal/validators/boolvalidators/graviton_validator.go) requires Fargate, while its [Fargate validator](https://github.com/seqeralabs/terraform-provider-seqera/blob/v0.42.0/internal/validators/objectvalidators/fargate_head_validator.go) requires Spot. Thus the same provider cannot provision the required ARM On-Demand fallback. Do not point ARM retries at an x86 queue. nf-canary remains deferred.

## Workflow

`.github/workflows/megatests.yml` validates pull requests. Relevant merges or a manual dispatch from `main` run the three workloads sequentially using a deployment matrix:

```text
apply forge/ (Spot + On-Demand CEs)
→ wait for AVAILABLE and read actual queues/head/role
→ apply runtime/ (manual CE with explicit queue selection)
→ wait for the manual CE and check both plans are empty
```

The pinned Seqera provider creates a CE and immediately describes it; it does not wait for Forge to finish. That is why the workflow keeps two Terraform stages with a small discovery step between them. Both stages run in one job per workload, with serialized applies and no approval stages or automatic teardown. CPU Fusion retains `PREFIX/forge.tfstate` and `PREFIX/runtime.tfstate`; additions use `PREFIX/cpu-s3/{forge,runtime}.tfstate` and `PREFIX/gpu-fusion/{forge,runtime}.tfstate`. No CPU resource addresses or default CE settings are changed by the expansion.

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

The AWS role needs S3 access to the six state objects listed above and their `.tflock` files. It does not need Batch queue-management permissions. Restrict OIDC trust to this repository/environment and the environment to `main`. The existing Platform AWS credential handles Forge infrastructure and launches. No AWS account-ID variable, Batch ARN configuration or private-repository token is needed. The action checks required configuration before applying anything; it does not create its own backend or OIDC role.

## Lifecycle and validation

Forge disposal is enabled as agreed. Rerunning the action recreates normally deleted test CEs, discovers their new queue names and reconciles the manual consumer. Partial failed Forge cleanup may still need repair. For a full cleanup, destroy `runtime/` before `forge/`. Fresh test names need no imports. The user has provisioned the CPU Fusion pilot locally; retain its two local state files and migrate them before GitHub takes ownership. Keep the same `name_prefix` and `work_dir` inputs during migration, including any local overrides; migration alone does not reconcile differing names.

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

After the setup works, add nf-canary to the workflow using the [nightly repository's launch pattern](https://github.com/seqeralabs/nf-seqerakit-nightly/tree/00467c184a59611fbb4f323ab51eb9fffce6edb9). Ordinary canary runs do not prove retry fallback or resume behavior; those checks follow separately. CPU Fusion provisioning has been reported successful by the user. S3 and GPU provisioning, provider normalization, empty live plans, workload execution and exercised fallback remain pending; the agent has performed no live apply or spend-bearing test. Global Cache remains disabled pending its separate early-access integration.

## Local expansion without changing the working CPU pilot

Use a separate directory and separate pair of state files for each new workload. Do not change `workload` in the existing CPU state, since doing so would replace that deployment. Copy the updated `terraform/megatests/` sources into each fresh directory, excluding `.terraform/`, states, generated tfvars and backend overrides; then add the same local backend override to each root as used for the CPU pilot.

Keep the token, workspace and credential environment variables from the successful CPU setup. For the S3 copy set:

```sh
export TF_VAR_workload=cpu-s3
export TF_VAR_name_prefix=nf-core-local-cpu-s3
export TF_VAR_work_dir=s3://nf-core-awsmegatests/test/cpu-s3
```

For a different, fresh GPU copy use `gpu-fusion`, `nf-core-local-gpu-fusion` and `s3://nf-core-awsmegatests/test/gpu-fusion` respectively. In each directory run:

```sh
terraform -chdir=forge init -lockfile=readonly
terraform -chdir=forge apply
terraform -chdir=forge output -json deployment > forge.json
python3 scripts/discover_queues.py --input forge.json --output runtime/deployment.auto.tfvars.json
terraform -chdir=runtime init -lockfile=readonly
terraform -chdir=runtime apply
terraform -chdir=runtime output -json deployment > deployment.json
python3 scripts/discover_queues.py --input deployment.json --runtime
terraform -chdir=forge plan -detailed-exitcode
terraform -chdir=runtime plan -detailed-exitcode
```

The applies above create live infrastructure and are operator-run steps. Preserve each directory's states. Switching back to the existing CPU directory also requires restoring its original workload/name/work-directory environment variables. Existing generated CPU discovery files without `workload` remain supported; the runtime defaults them to `cpu-fusion`.
