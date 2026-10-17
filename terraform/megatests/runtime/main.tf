# Keep the original resource address so the existing CPU pilot stays in state.
resource "seqera_aws_batch_ce" "cpu_fusion" {
  name           = var.deployment.name_prefix
  workspace_id   = tonumber(var.deployment.workspace_id)
  credentials_id = var.deployment.credentials_id
  description    = var.deployment.workload == "cpu-fusion" ? "CPU Fusion test CE with explicit Spot-to-On-Demand routing." : "${var.deployment.workload} test CE with explicit Spot-to-On-Demand routing."
  config = {
    region               = var.deployment.region
    work_dir             = var.deployment.work_dir
    compute_queue        = var.deployment.spot.queue_name
    head_queue           = var.deployment.spot.head_queue
    execution_role       = var.deployment.spot.execution_role
    head_job_role        = var.deployment.spot.head_job_role
    cli_path             = var.deployment.spot.cli_path
    enable_wave          = true
    enable_fusion        = var.deployment.workload != "cpu-s3"
    nvme_storage_enabled = var.deployment.workload != "cpu-s3"
    fusion_snapshots     = var.deployment.workload == "cpu-fusion"
    nextflow_config = templatefile("${path.module}/queue.config.tftpl", {
      spot_queue     = var.deployment.spot.queue_name
      ondemand_queue = var.deployment.ondemand.queue_name
      fusion_enabled = var.deployment.workload != "cpu-s3"
    })
  }
}

output "deployment" {
  description = "Manual CE and actual Forge queue identifiers for launches and #220."
  value = {
    workspace_id        = var.deployment.workspace_id
    workload            = var.deployment.workload
    work_dir            = var.deployment.work_dir
    spot_ce_id          = seqera_aws_batch_ce.cpu_fusion.compute_env_id
    spot_ce_name        = seqera_aws_batch_ce.cpu_fusion.name
    ondemand_ce_id      = var.deployment.ondemand.ce_id
    ondemand_ce_name    = var.deployment.ondemand.ce_name
    spot_queue_name     = var.deployment.spot.queue_name
    ondemand_queue_name = var.deployment.ondemand.queue_name
  }
}
