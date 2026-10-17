variable "deployment" {
  description = "Actual Forge outputs discovered by scripts/discover_queues.py; never predict queue names from CE IDs."
  type = object({
    workspace_id   = string
    credentials_id = string
    region         = string
    work_dir       = string
    name_prefix    = string
    workload       = optional(string, "cpu-fusion")
    spot = object({
      queue_name     = string
      head_queue     = string
      execution_role = string
      head_job_role  = optional(string)
      cli_path       = optional(string)
    })
    ondemand = object({
      queue_name = string
      ce_id      = string
      ce_name    = string
    })
  })
  validation {
    condition     = contains(["cpu-fusion", "cpu-s3", "gpu-fusion"], var.deployment.workload)
    error_message = "The discovered workload must be cpu-fusion, cpu-s3, or gpu-fusion."
  }
  validation {
    condition     = var.deployment.workload != "cpu-s3" || try(length(trimspace(var.deployment.spot.cli_path)) > 0, false)
    error_message = "Non-Fusion S3 staging needs the actual Forge AWS CLI path from discovery."
  }
  validation {
    condition = (
      can(regex("^[A-Za-z0-9_-]+$", var.deployment.spot.queue_name)) &&
      can(regex("^[A-Za-z0-9_-]+$", var.deployment.ondemand.queue_name)) &&
      var.deployment.spot.queue_name != var.deployment.ondemand.queue_name
    )
    error_message = "Explicit distinct Spot and On-Demand queue names are required."
  }
}
