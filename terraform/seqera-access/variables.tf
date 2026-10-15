variable "org_id" {
  type        = string
  sensitive   = true
  description = "Seqera organization numeric ID, supplied through a protected CI variable."

  validation {
    condition     = can(regex("^[0-9]+$", var.org_id)) && can(tonumber(var.org_id)) && try(tonumber(var.org_id), 0) > 0
    error_message = "org_id must be a positive numeric Seqera ID."
  }
}

variable "workspace_id" {
  type        = string
  sensitive   = true
  description = "Seqera workspace numeric ID, supplied through a protected CI variable."

  validation {
    condition     = can(regex("^[0-9]+$", var.workspace_id)) && can(tonumber(var.workspace_id)) && try(tonumber(var.workspace_id), 0) > 0
    error_message = "workspace_id must be a positive numeric Seqera ID."
  }
}

variable "identity_map" {
  type        = map(string)
  sensitive   = true
  description = "Private map of lowercase GitHub handles to existing Seqera organization member IDs."
  default     = {}
}

variable "members_manifest_path" {
  type        = string
  description = "Path relative to this root for the public GitHub-handle membership manifest."
  default     = "members.json"
}
