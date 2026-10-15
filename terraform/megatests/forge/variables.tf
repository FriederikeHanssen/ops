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
variable "account_id" {
  type        = string
  description = "Expected AWS account for the queues returned by Forge."
  validation {
    condition     = can(regex("^[0-9]{12}$", var.account_id))
    error_message = "account_id must be a 12-digit string."
  }
}
variable "region" {
  type    = string
  default = "eu-west-1"
}
variable "work_dir" {
  type        = string
  description = "Existing S3 work location, using a test prefix during this rollout."
  default     = "s3://nf-core-awsmegatests/test/cpu-fusion"
}
variable "name_prefix" {
  type        = string
  default     = "nf-core-test-cpu-fusion"
  description = "Test namespace; existing production CEs are not adopted."
  validation {
    condition     = can(regex("^[A-Za-z0-9_-]{1,80}$", var.name_prefix))
    error_message = "Use a Batch-compatible name prefix of up to 80 characters."
  }
}
