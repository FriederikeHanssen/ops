# Forge owns its AWS Batch, IAM, networking and launch-template resources.
# Terraform owns the Platform carrier definitions and can recreate deleted CEs.
locals {
  name_prefix = coalesce(var.name_prefix, "nf-core-test-${var.workload}")
  work_dir    = coalesce(var.work_dir, "s3://nf-core-awsmegatests/test/${var.workload}")
  fusion      = var.workload != "cpu-s3"
  instances = {
    # Seqera's recommended snapshot-compatible CPU sizes.
    cpu-fusion = ["c6id.4xlarge", "c6id.8xlarge", "c6id.12xlarge", "m6id.4xlarge", "m6id.8xlarge", "r6id.2xlarge"]
    cpu-s3     = ["c6i", "m6i", "r6i"]
    # Preserve the historical GPU-capable families on both capacity types.
    # Snapshots are off: GPU restore requires a single GPU instance type.
    gpu-fusion = ["g4dn", "g5", "c6id", "m6id", "r6id"]
  }
}

resource "seqera_aws_batch_ce" "carrier" {
  for_each = { spot = "SPOT", ondemand = "EC2" }

  name           = "${local.name_prefix}-${each.key}-forge"
  workspace_id   = tonumber(var.workspace_id)
  credentials_id = var.credentials_id
  description    = var.workload == "cpu-fusion" ? "CPU Fusion test infrastructure for nf-core/ops #216; managed by Terraform." : "${var.workload} test infrastructure for nf-core/ops #216; managed by Terraform."

  config = {
    region               = var.region
    work_dir             = local.work_dir
    enable_wave          = true
    enable_fusion        = local.fusion
    nvme_storage_enabled = local.fusion
    fusion_snapshots     = var.workload == "cpu-fusion" && each.key == "spot"
    forge = {
      type                 = each.value
      min_cpus             = 0
      max_cpus             = var.workload == "gpu-fusion" ? 500 : 1000
      instance_types       = local.instances[var.workload]
      gpu_enabled          = var.workload == "gpu-fusion"
      arm64_enabled        = false
      fargate_head_enabled = false
      ebs_boot_size        = 50
      efs_create           = false
      dispose_on_deletion  = true
      # Keep work_dir last: Platform appends it in this position.
      allow_buckets = [
        "s3://ngi-igenomes",
        "s3://annotation-cache/",
        "s3://nf-core-awsmegatests",
        local.work_dir,
      ]
    }
  }
}

output "deployment" {
  description = "Readiness/discovery input. Queue names are read from Platform after Forge completes."
  value = {
    workspace_id   = var.workspace_id
    credentials_id = var.credentials_id
    region         = var.region
    work_dir       = local.work_dir
    name_prefix    = local.name_prefix
    workload       = var.workload
    carriers = {
      for kind, ce in seqera_aws_batch_ce.carrier : kind => {
        id   = ce.compute_env_id
        name = ce.name
      }
    }
  }
}
