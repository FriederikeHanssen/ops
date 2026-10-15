variable "org_id" {
  type        = number
  description = "Numeric Seqera organization ID."

  validation {
    condition     = var.org_id > 0 && floor(var.org_id) == var.org_id
    error_message = "org_id must be a positive integer."
  }
}

variable "workspace_id" {
  type        = number
  description = "Numeric Seqera workspace ID receiving the team role grants."

  validation {
    condition     = var.workspace_id > 0 && floor(var.workspace_id) == var.workspace_id
    error_message = "workspace_id must be a positive integer."
  }
}
