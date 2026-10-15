# Explicit CPU/GPU Spot queues — #216

This additive pilot creates **two native AWS Batch job queues**. Each references the actual backing compute environments of an existing Forge Spot queue. Existing Forge Spot and On-Demand CEs, queues, IAM roles, instance profiles, launch templates, networking and storage remain externally owned. Nothing is imported, disabled, replaced or deleted by this root. ARM is outside this pilot.

The queues can be created before #220 registers manual Platform CEs, so both branches of `process.queue` have real names. This avoids the `null` Spot workaround without cloning unverified GPU or Fusion infrastructure. It is a queue-only ownership boundary: the required backing infrastructure already exists and remains under Forge. It is not a completed migration of AWS compute environments into Terraform. If dedicated new Forge carriers are preferred, create and validate those separately first, then supply their actual queues here; do not create a carrier and guess its generated names in the consuming CE.

## Live baseline and ownership

Read through Seqera MCP on **2026-10-15**, in [nf-core/AWSmegatests](https://cloud.seqera.io/orgs/nf-core/workspaces/AWSmegatests/compute-envs). All four CEs reported `AVAILABLE`, region `eu-west-1`, work directory `s3://nf-core-awsmegatests`, Wave/Fusion/NVMe enabled. The example input contains actual observed names, not reconstructed Forge names.

| Workload | Spot Platform CE         | Spot queue                               | On-Demand Platform CE / queue                                  |
| -------- | ------------------------ | ---------------------------------------- | -------------------------------------------------------------- |
| CPU      | `29o9qiv0F5P6DSWkbWgj7w` | `TowerForge-29o9qiv0F5P6DSWkbWgj7w-work` | `6nSba1hDuNFP08JP7SjigJ` / `TowerForge-6nSba1hDuNFP08JP7SjigJ` |
| GPU      | `2CPfB2svbMkdolzS4Mahb7` | `TowerForge-2CPfB2svbMkdolzS4Mahb7-work` | `4qY173IE6egkoaj4jGy6Me` / `TowerForge-4qY173IE6egkoaj4jGy6Me` |

Both live Spot configs use `task.attempt > 1 ? '<On-Demand name>' : null`. CPU Forge specs use `c6id,m6id,r6id`, min/max vCPUs `0/1000`. GPU specs use `g4dn,g5,c6id,m6id,r6id`, min/max `0/500`, GPUs enabled and 50 GiB boot disk. On-Demand matches those workload families/limits. GPU queues deliberately retain CPU families for mixed pipelines. A GPU task must still request a GPU through Nextflow's `accelerator` directive; a GPU queue alone does not request GPU hardware.

Platform also reports the exact backing AWS CE ARNs in `forgedResources`. The new aliases resolve associations through AWS `DescribeJobQueues`, rather than inferring them from Platform IDs. They inherit all Spot associations and their orders, priority, fair-share policy (if present), and job-state limit actions. They share the existing CE capacity limits, rather than adding another 1000/500 vCPUs. Queue-level fairness still needs a pilot: two queues sharing a CE can affect scheduling. Existing source queues stay available.

| Resource                                                             | Pilot action / owner                                                   | Import plan                                                                                                                                                                                |
| -------------------------------------------------------------------- | ---------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `aws_batch_job_queue.spot["cpu"]`, `["gpu"]`                         | Create new additive queues; this root owns them                        | No import for fresh pilot. After a partially completed apply, recover state first; if the exact pilot queue exists outside state, inspect it and import by its actual ARN before planning. |
| Forge Spot backing AWS CEs                                           | Reference through AWS data sources; Forge owns lifecycle               | Do not import into this root. A future ownership transfer requires a separate handover of Forge disposal and all dependent resources.                                                      |
| On-Demand queues/backing CEs                                         | Reference by verified existing names; Forge owns them                  | No import here; #220 must retain the carrier CEs.                                                                                                                                          |
| IAM, profiles, launch templates, VPC/subnets/security groups, bucket | Reference indirectly through existing CEs; existing owners retain them | No duplicate declarations or guessed replacements. Direct AWS inventory and owner confirmation required before apply.                                                                      |
| Platform CEs, credentials, Launchpad/workflow variables              | #220 owns registration and cutover                                     | Import existing Platform objects only under that separately reviewed migration; never overwrite them to pilot.                                                                             |

All four live carriers have `disposeOnDeletion=true`. **Do not delete a carrier CE or let another reconciler destroy its resources** while either the old or pilot configuration uses them. The pilot queue's `prevent_destroy` cannot protect external Forge resources. Retaining these carriers is a rollout requirement, not a claim that this root can enforce their lifecycle. A Platform-only disabled carrier is not assumed to be supported; do not disable an AWS compute environment as a substitute, because that stops scheduling. This explicit dependency is the tradeoff for preserving the proven compute setup during the pilot.

If recovering an orphaned pilot queue, after separate authorization for state mutation:

```sh
terraform import 'aws_batch_job_queue.spot["cpu"]' ACTUAL_PILOT_QUEUE_ARN
```

Review a plan after import; stop on any replacement or deletion. Never import a production Forge source queue at this address.

## State and local checks

There was no committed Terraform backend in the inspected upstream checkout. This root follows the documented S3 convention (`use_lockfile=true`) and the proposed independent-root structure in `docs/megatests-implementation-plans.md`. It does not depend on the uncommitted #219 implementation. Bootstrap or confirm a private, encrypted, versioned S3 backend and locking permissions separately. Use a **dedicated state key**, distinct from access management and #220; configure bucket, key and backend region privately in ignored `backend.hcl`. Supply AWS credentials using the approved operator/OIDC environment, never tfvars. The provider requires the expected account ID. Keep plans/state private.

```sh
terraform init -backend=false -lockfile=readonly
terraform fmt -check -recursive
terraform validate
terraform test
```

Run from this directory. Tests use an AWS mock and plan commands only. The lockfile pins the official AWS provider. No workflow applies this root automatically. For a credentialed read-only plan, first confirm AWS inventory below, copy the example to ignored `terraform.tfvars`, initialize the verified S3 backend, and run:

```sh
terraform init -reconfigure -backend-config=backend.hcl
terraform plan -out=pilot.tfplan
terraform show pilot.tfplan
```

A first live plan must contain exactly two queue creates, zero changes/deletes to existing resources, and expected source reads. Backend initialization creates a state connection, not infrastructure. Do not apply without explicit authorization. With unchanged inputs/state, repeat the pre-apply plan and compare resource actions/values. After an authorized apply, run a full refreshed plan and require no changes; repeat after integration. Mock plan passes do not establish live plan stability.

## Required AWS inventory before apply

Seqera's `AVAILABLE` status is **not** direct AWS validation. Using an authorized AWS identity, record privately:

1. `sts get-caller-identity`; expected account `728131696474`, region `eu-west-1`.
2. `batch describe-job-queues` for all four observed queues. Verify `ENABLED/VALID`, associations, scheduling policy, priorities, job-state actions, owner tags and quota headroom for two more queues.
3. `batch describe-compute-environments` for every associated ARN. Spot associations must use `SPOT`; On-Demand must use `EC2`, not Fargate. Check instance families, GPU capability, min/max vCPUs, service role, instance profile, AMI, launch template ID/version, subnets/security groups and ECS cluster. The Terraform data source exposes state/status but not these compute-resource details, so its preconditions cannot replace this check.
4. Describe each exact launch-template version and AMI. Confirm x86_64, ECS registration/bootstrap, NVIDIA drivers/GPU AMI and GPU agent support for GPU paths, Fusion/NVMe setup, boot disk and any custom user data. Confirm both fallback and Spot paths meet the same workload CPU, RAM, GPU and disk requirements.
5. Inspect IAM roles/policies/profile and launch identity permissions for both pilot queue ARNs: SubmitJob, DescribeJobs/queues/CEs, RegisterJobDefinition, logs, PassRole and required S3 access. Check resource-scoped conditions/tags against new queue names; existing Forge permissions may not authorize aliases. Do not broaden permissions implicitly.
6. Inspect subnet routes, free IPs, security groups and egress/endpoints for S3, ECS, ECR, logs, Wave/Fusion. Record owners of shared networking/storage. Freeze competing reconcilers for carrier retirement through the pilot.

The configuration requires both source queues and all backing CEs to be `ENABLED/VALID`, in the expected account/region, with distinct Spot/On-Demand associations. It cannot verify AWS permissions or GPU drivers without this inventory and execution evidence.

## Contract for #220

After AWS queue apply, obtain `terraform output -json queue_contract` privately and pass its values as typed inputs to #220. Prefer explicit input wiring or a reviewed handoff JSON with a recorded state serial; access to `terraform_remote_state` exposes the entire state snapshot. Re-read on subsequent plans to detect carrier changes. Never copy a predicted Forge queue name.

Each `cpu`/`gpu` object contains `region`, `spot_queue_name`, `spot_queue_arn`, `spot_compute_environment_arns`, `ondemand_queue_name`, `ondemand_queue_arn`, `ondemand_compute_environment_arns`, `head_queue_name` and `routing_config`. Schema contract: v1. Names are for Platform/Nextflow; ARNs are for AWS evidence and IAM. The On-Demand lookup runs only after its Forge CE is already `AVAILABLE`, so there is no circular creation dependency. If #220 creates a new On-Demand carrier, finish that stage and export its actual `computeQueue` before this root plans; only then create the manual consumer. Keep Forge disposal under explicit review.

For the documented `seqeralabs/seqera` 0.42.0 `seqera_aws_batch_ce` manual interface:

| Field                                                        | Source / requirement                                                                                                                                                                                                                                                                                                   |
| ------------------------------------------------------------ | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `workspace_id`, `credentials_id`                             | Verified workspace and existing credential inputs owned by #220; no credential secrets in this root                                                                                                                                                                                                                    |
| `config.region`, `work_dir`                                  | Output region; preserve live work directory                                                                                                                                                                                                                                                                            |
| `config.compute_queue`                                       | Workload's `spot_queue_name` (queue **name**, not ARN)                                                                                                                                                                                                                                                                 |
| `config.head_queue`                                          | Workload's `head_queue_name`; this is the observed On-Demand EC2 queue                                                                                                                                                                                                                                                 |
| `config.execution_role`, `head_job_role`, `compute_job_role` | Inventory verified compatible IAM role ARNs before registration. Do not reuse the Fargate head role automatically. Live On-Demand `executionRole` is available from its CE export; the other job-role choices require AWS IAM review.                                                                                  |
| Wave/Fusion/NVMe                                             | Preserve live requirements using `enable_wave`, `enable_fusion`, `nvme_storage_enabled`; validate manual bootstrap                                                                                                                                                                                                     |
| `config.forge`                                               | Omit for manual registration. Forge carrier CEs remain separate resources.                                                                                                                                                                                                                                             |
| Queue-selection fragment                                     | Use output `routing_config` as a separately versioned config fragment through the approved config/snapshots delivery mechanism; validate the fully merged effective config. Repository instructions prohibit embedding config in `nextflowConfig`. #220 must resolve delivery without modifying legacy seqerakit here. |

The routing fragment selects `task.attempt > 1 ? '<actual On-Demand>' : '<actual pilot Spot>'`. CPU and GPU have separate pairs. It changes neither `errorStrategy`, `maxRetries`, `maxSpotAttempts`, resource directives nor submission timeouts. It handles Nextflow execution retries under the existing boundary; AWS-internal retries keep the same queue and submission starvation does not increment `task.attempt`. No general retry/resume redesign is included.

[Manual mode documentation](https://docs.seqera.io/platform-cloud/enterprise/advanced-topics/manual-aws-batch-setup) requires EC2 heads and excludes manual Fargate heads. The current Spot heads are Fargate, so the contract explicitly uses the existing On-Demand EC2 head/compute queue. GPU head jobs do not request GPUs; validate head scheduling alongside tasks. Provider 0.42.0 manual fields are documented in its [manual example](https://github.com/seqeralabs/terraform-provider-seqera/blob/v0.42.0/examples/resources/seqera_aws_batch_ce/resource_manual.tf). Config changes force Platform CE replacement in that version: #220 must create separately named pilots, leaving old IDs and primary settings unchanged.

## Pilot, validation and rollback

Apply, test launches, cutover and deletion require explicit authorization. Once authorized:

1. Review the AWS inventory and two-create plan, then apply the saved plan. Capture new queue ARNs and VALID state. Do not change existing queues or Platform references.
2. Under #220, create separately named CPU/GPU manual CEs using the contract. Validate IAM, EC2 heads, complete effective config, base policy, Wave/Fusion/NVMe and per-process GPU requests. Pipeline-specific queue selectors can override defaults, so inspect the rendered config for representative workflows.
3. Make at least three fresh CPU launches and three fresh GPU launches. Record Platform workflow ID, Nextflow version/config digest, task attempt, AWS Batch job ID, actual `DescribeJobs.jobQueue`, backing CE/instance type and GPU resource requirement. Require pilot Spot queue on first attempts. `nvidia-smi` must work for GPU tasks. Do not infer routing from the Platform CE name.
4. Exercise CPU and GPU fallback using `validation/main.nf` plus the workload's rendered routing fragment and `validation/nextflow.config`. Default probe mode does not fail; `--exercise_fallback true` deliberately exits 143 on attempt one. GPU mode also requires `--gpu true --gpu_image APPROVED_CUDA_IMAGE`. The fixture requests one GPU and runs `nvidia-smi` on both attempts. Its isolated policy disables AWS Spot retries and permits one Nextflow retry so the test is bounded; this is not a production policy change. Launch through the pilot Platform CE with an approved work directory/container. These tests incur AWS costs and have **not** been run.
5. Match task IDs/native Batch IDs and queue ARNs: failed first attempt must use pilot Spot, successful second attempt must use the matching On-Demand queue. Confirm GPU hardware/driver output on both. This tests an execution retry, not actual reclamation or capacity starvation. Test real reclamation separately if required. A resume regression should use the same work/cache directory and completed probe session; verify cached tasks, new task routing and retained permissions, without changing cache policy.
6. Require empty refreshed Terraform plans twice. Attach sanitized evidence below. Only after review and separate authorization switch the exact consuming CE IDs/Launchpad/GitHub variables in #220. Retain old references and all carriers for the agreed rollback window.

Rollback before cutover: stop using the pilots; original CEs/queues remain available. After cutover: restore recorded old CE references, leave running jobs to finish, and stop new submissions to pilots. Never disable a shared backing AWS CE to roll back. Drain pilot queues and confirm no running/pending jobs before separately authorized cleanup. `prevent_destroy` is intentional; deletion needs a reviewed change. Retiring a Forge carrier additionally requires either a complete ownership transfer or proving that no old/new queues depend on any of its resources.

## Evidence and separate findings

| Check                                                                      | Status on 2026-10-15                                                                                                                                                                 |
| -------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Issues #216/#220, repo instructions, historical CPU/GPU specs              | Read                                                                                                                                                                                 |
| Live Platform CPU/GPU Spot/On-Demand config via MCP                        | Read; null workaround and exact queue names confirmed                                                                                                                                |
| AWS provider schema validation                                             | Passed locally with Terraform 1.14.5 / AWS provider 6.69.0                                                                                                                           |
| Mock plan tests                                                            | Passed: explicit pair/GPU associations, preserved queue policy, null rejection, shared fallback rejection, unavailable fallback, invalid backing compute and wrong-account rejection |
| Direct AWS IAM/network/AMI/queue inventory                                 | Pending; no AWS credentials exposed in session and installed CLI is incompatible with host                                                                                           |
| Credentialed plan / repeated live plan stability                           | Pending AWS inventory/backend access; mock plans are not live evidence                                                                                                               |
| Apply, manual Platform CE registration, repeated CPU/GPU launches/fallback | Pending explicit authorization and #220 integration                                                                                                                                  |
| Resume, reclamation and cutover/rollback exercise                          | Pending; no claim of coverage                                                                                                                                                        |

Related findings reported separately, unchanged in this PR:

- Live On-Demand CEs have `fusionSnapshots=true`, whereas [AWS Batch documentation](https://docs.seqera.io/platform-cloud/compute-envs/aws-batch) says not to enable Snapshots on On-Demand. Verify actual deployed behavior before changing it in #220.
- `aws.batch.maxSpotAttempts=5` performs AWS-internal retries that do not increment Nextflow's `task.attempt`; fallback can be delayed. Existing exit-code retry filtering can also terminate failures with no matching exit status. [Seqera interruption guidance](https://docs.seqera.io/platform-cloud/compute-envs/aws-spot-interruptions) explains these distinctions. No retry policy is changed here.
- GPU compatibility is reported by live Forge specs, not yet proved against the actual AMI/agent or task job definitions. A queue name cannot compensate for a missing GPU resource request.
