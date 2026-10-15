variable "deployment" {
  description = "Actual Forge outputs discovered by scripts/discover_queues.py; never predict queue names from CE IDs."
  type = object({
    workspace_id   = string
    credentials_id = string
    account_id     = string
    region         = string
    work_dir       = string
    name_prefix    = string
    spot = object({
      queue_name     = string
      queue_arn      = string
      head_queue     = string
      execution_role = string
      head_job_role  = optional(string)
    })
    ondemand = object({
      queue_name = string
      queue_arn  = string
      ce_id      = string
      ce_name    = string
    })
  })
  validation {
    condition = (
      can(regex("^[A-Za-z0-9_-]+$", var.deployment.spot.queue_name)) &&
      can(regex("^[A-Za-z0-9_-]+$", var.deployment.ondemand.queue_name)) &&
      var.deployment.spot.queue_name != var.deployment.ondemand.queue_name &&
      var.deployment.spot.queue_arn != var.deployment.ondemand.queue_arn
    )
    error_message = "Explicit distinct Spot and On-Demand names and ARNs are required."
  }
}
