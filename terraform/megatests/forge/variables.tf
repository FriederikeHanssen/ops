variable "workspace_id" {
  type        = string
  description = "Existing AWSmegatests workspace ID. This root does not manage workspace access."
  validation {
    condition     = can(regex("^[0-9]+$", var.workspace_id))
    error_message = "workspace_id must be a numeric string."
  }
}
variable "credentials_id" {
  type        = string
  description = "Existing Platform AWS credential ID; the credential's secret remains in Platform."
}
variable "region" {
  type    = string
  default = "eu-west-1"
}
variable "work_dir" {
  type        = string
  description = "Existing S3 work location, using a test prefix during this rollout."
  default     = null
}
variable "name_prefix" {
  type        = string
  default     = null
  description = "Test namespace; existing production CEs are not adopted."
  validation {
    condition     = var.name_prefix == null || can(regex("^[A-Za-z0-9_-]{1,80}$", var.name_prefix))
    error_message = "Use a Batch-compatible name prefix of up to 80 characters."
  }
}

variable "workload" {
  type        = string
  default     = "cpu-fusion"
  description = "One independent three-CE deployment. Use separate Terraform state for each workload."
  validation {
    condition     = contains(["cpu-fusion", "cpu-s3", "gpu-fusion"], var.workload)
    error_message = "Choose cpu-fusion, cpu-s3, or gpu-fusion. ARM On-Demand is blocked by provider 0.42.0's Graviton/Fargate constraints."
  }
}
