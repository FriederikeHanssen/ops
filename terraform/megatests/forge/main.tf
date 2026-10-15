# Forge owns its AWS Batch, IAM, networking and launch-template resources.
# Terraform owns the Platform carrier definitions and can recreate deleted CEs.
resource "seqera_aws_batch_ce" "carrier" {
  for_each = { spot = "SPOT", ondemand = "EC2" }

  name           = "${var.name_prefix}-${each.key}-forge"
  workspace_id   = tonumber(var.workspace_id)
  credentials_id = var.credentials_id
  description    = "CPU Fusion test infrastructure for nf-core/ops #216; managed by Terraform."

  config = {
    region               = var.region
    work_dir             = var.work_dir
    enable_wave          = true
    enable_fusion        = true
    nvme_storage_enabled = true
    fusion_snapshots     = false
    forge = {
      type                 = each.value
      min_cpus             = 0
      max_cpus             = 1000
      instance_types       = ["c6id", "m6id", "r6id"]
      gpu_enabled          = false
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
        var.work_dir,
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
    work_dir       = var.work_dir
    name_prefix    = var.name_prefix
    carriers = {
      for kind, ce in seqera_aws_batch_ce.carrier : kind => {
        id   = ce.compute_env_id
        name = ce.name
      }
    }
  }
}
