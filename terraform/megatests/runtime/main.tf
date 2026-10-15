data "aws_batch_job_queue" "spot" {
  name = var.deployment.spot.queue_name
}
data "aws_batch_job_queue" "ondemand" {
  name = var.deployment.ondemand.queue_name
}

# Native AWS queue ownership stays here; Forge owns the backing compute.
resource "aws_batch_job_queue" "spot" {
  name                  = "${var.deployment.name_prefix}-spot"
  state                 = "ENABLED"
  priority              = data.aws_batch_job_queue.spot.priority
  scheduling_policy_arn = data.aws_batch_job_queue.spot.scheduling_policy_arn

  dynamic "compute_environment_order" {
    for_each = data.aws_batch_job_queue.spot.compute_environment_order
    content {
      order               = compute_environment_order.value.order
      compute_environment = compute_environment_order.value.compute_environment
    }
  }
  dynamic "job_state_time_limit_action" {
    for_each = data.aws_batch_job_queue.spot.job_state_time_limit_action
    content {
      action           = job_state_time_limit_action.value.action
      max_time_seconds = job_state_time_limit_action.value.max_time_seconds
      reason           = job_state_time_limit_action.value.reason
      state            = job_state_time_limit_action.value.state
    }
  }
  tags = { ManagedBy = "Terraform", Project = "nf-core-megatests-test" }
  lifecycle {
    precondition {
      condition = alltrue([
        for queue in [data.aws_batch_job_queue.spot, data.aws_batch_job_queue.ondemand] :
        queue.state == "ENABLED" && queue.status == "VALID" && length(queue.compute_environment_order) > 0
      ])
      error_message = "Forge queues must be ready with backing compute before registering the consumer CE."
    }
    precondition {
      condition = (
        data.aws_batch_job_queue.spot.arn == var.deployment.spot.queue_arn &&
        data.aws_batch_job_queue.ondemand.arn == var.deployment.ondemand.queue_arn
      )
      error_message = "AWS queue identities differ from the actual Platform Forge outputs."
    }
  }
}

resource "seqera_aws_batch_ce" "cpu_fusion" {
  name           = var.deployment.name_prefix
  workspace_id   = tonumber(var.deployment.workspace_id)
  credentials_id = var.deployment.credentials_id
  description    = "CPU Fusion test CE with explicit Spot-to-On-Demand routing."
  config = {
    region               = var.deployment.region
    work_dir             = var.deployment.work_dir
    compute_queue        = aws_batch_job_queue.spot.name
    head_queue           = var.deployment.spot.head_queue
    execution_role       = var.deployment.spot.execution_role
    head_job_role        = var.deployment.spot.head_job_role
    enable_wave          = true
    enable_fusion        = true
    nvme_storage_enabled = true
    fusion_snapshots     = false
    nextflow_config = templatefile("${path.module}/queue.config.tftpl", {
      spot_queue     = aws_batch_job_queue.spot.name
      ondemand_queue = data.aws_batch_job_queue.ondemand.name
    })
  }
}

resource "seqera_pipeline" "canary" {
  name         = "${var.deployment.name_prefix}-canary"
  workspace_id = tonumber(var.deployment.workspace_id)
  description  = "nf-canary for the CPU Fusion test CEs."
  launch = {
    pipeline       = "https://github.com/seqeralabs/nf-canary"
    revision       = "0.2.0"
    compute_env_id = seqera_aws_batch_ce.cpu_fusion.compute_env_id
    work_dir       = var.deployment.work_dir
  }
}

output "deployment" {
  value = {
    workspace_id                  = var.deployment.workspace_id
    work_dir                      = var.deployment.work_dir
    pipeline_name                 = seqera_pipeline.canary.name
    spot_ce_id                    = seqera_aws_batch_ce.cpu_fusion.compute_env_id
    spot_ce_name                  = seqera_aws_batch_ce.cpu_fusion.name
    ondemand_ce_id                = var.deployment.ondemand.ce_id
    ondemand_ce_name              = var.deployment.ondemand.ce_name
    spot_queue_name               = aws_batch_job_queue.spot.name
    spot_queue_arn                = aws_batch_job_queue.spot.arn
    ondemand_queue_name           = data.aws_batch_job_queue.ondemand.name
    ondemand_queue_arn            = data.aws_batch_job_queue.ondemand.arn
    spot_compute_environment_arns = [for association in aws_batch_job_queue.spot.compute_environment_order : association.compute_environment]
  }
}
