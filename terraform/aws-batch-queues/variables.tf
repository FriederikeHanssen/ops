variable "region" {
  type        = string
  description = "Region containing the verified Forge infrastructure."
  default     = "eu-west-1"
}

variable "account_id" {
  type        = string
  description = "Expected AWS account; prevents planning against another account."
  validation {
    condition     = can(regex("^[0-9]{12}$", var.account_id))
    error_message = "Supply the verified 12-digit AWS account ID."
  }
}

variable "name_prefix" {
  type        = string
  description = "Unique additive pilot namespace. Existing Forge queue names must not be reused."
  default     = "nf-core-megatests-pilot"
  validation {
    condition     = can(regex("^[A-Za-z0-9_-]{1,100}$", var.name_prefix))
    error_message = "name_prefix must contain 1–100 AWS Batch name characters."
  }
}

variable "queues" {
  description = "Actual queue names read from the live Platform manual attributes, after Forge is AVAILABLE. Forge owns all source infrastructure."
  type = map(object({
    spot     = string
    ondemand = string
  }))
  validation {
    condition = (
      toset(keys(var.queues)) == toset(["cpu", "gpu"]) &&
      alltrue([for pair in var.queues :
        can(regex("^[A-Za-z0-9_-]{1,128}$", pair.spot)) &&
        can(regex("^[A-Za-z0-9_-]{1,128}$", pair.ondemand)) &&
        pair.spot != pair.ondemand
      ]) &&
      length(toset(flatten([for pair in var.queues : [pair.spot, pair.ondemand]]))) == 4
    )
    error_message = "Supply cpu and gpu with four distinct, explicit AWS queue names, not ARNs or null."
  }
}
