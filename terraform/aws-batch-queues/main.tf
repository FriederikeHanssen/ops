# Queue aliases deliberately share the existing Forge compute environments.
# No AWS CE, launch template, IAM, network or Platform ownership is transferred.
data "aws_batch_job_queue" "spot" {
  for_each = var.queues
  name     = each.value.spot
}

data "aws_batch_job_queue" "ondemand" {
  for_each = var.queues
  name     = each.value.ondemand
}

locals {
  backing_environments = toset(flatten([
    for queue in concat(values(data.aws_batch_job_queue.spot), values(data.aws_batch_job_queue.ondemand)) :
    [for association in queue.compute_environment_order : association.compute_environment]
  ]))
}

data "aws_batch_compute_environment" "backing" {
  for_each = local.backing_environments
  name     = element(split("/", each.value), 1)
}

resource "aws_batch_job_queue" "spot" {
  for_each = var.queues

  name                  = "${var.name_prefix}-${each.key}-spot"
  state                 = "ENABLED"
  priority              = data.aws_batch_job_queue.spot[each.key].priority
  scheduling_policy_arn = data.aws_batch_job_queue.spot[each.key].scheduling_policy_arn

  dynamic "compute_environment_order" {
    for_each = data.aws_batch_job_queue.spot[each.key].compute_environment_order
    content {
      order               = compute_environment_order.value.order
      compute_environment = compute_environment_order.value.compute_environment
    }
  }

  dynamic "job_state_time_limit_action" {
    for_each = data.aws_batch_job_queue.spot[each.key].job_state_time_limit_action
    content {
      action           = job_state_time_limit_action.value.action
      max_time_seconds = job_state_time_limit_action.value.max_time_seconds
      reason           = job_state_time_limit_action.value.reason
      state            = job_state_time_limit_action.value.state
    }
  }

  tags = {
    ManagedBy = "Terraform"
    Project   = "nf-core-megatests"
    Issue     = "216"
    Workload  = each.key
  }

  lifecycle {
    prevent_destroy = true
    precondition {
      condition = alltrue([
        for queue in [data.aws_batch_job_queue.spot[each.key], data.aws_batch_job_queue.ondemand[each.key]] :
        queue.state == "ENABLED" && queue.status == "VALID" && length(queue.compute_environment_order) > 0 &&
        startswith(queue.arn, "arn:aws:batch:${var.region}:${var.account_id}:job-queue/")
      ])
      error_message = "Source queues must be enabled, valid, backed by compute and in the expected account/region."
    }
    precondition {
      condition = alltrue([
        for association in concat(
          tolist(data.aws_batch_job_queue.spot[each.key].compute_environment_order),
          tolist(data.aws_batch_job_queue.ondemand[each.key].compute_environment_order)
        ) :
        data.aws_batch_compute_environment.backing[association.compute_environment].state == "ENABLED" &&
        data.aws_batch_compute_environment.backing[association.compute_environment].status == "VALID"
      ])
      error_message = "All backing compute environments must be enabled and valid."
    }
    precondition {
      condition     = !contains(flatten([for pair in var.queues : [pair.spot, pair.ondemand]]), "${var.name_prefix}-${each.key}-spot")
      error_message = "The pilot must use new queue names; do not adopt production Forge queues."
    }
    precondition {
      condition = length(setintersection(
        toset([for association in data.aws_batch_job_queue.spot[each.key].compute_environment_order : association.compute_environment]),
        toset([for association in data.aws_batch_job_queue.ondemand[each.key].compute_environment_order : association.compute_environment])
      )) == 0
      error_message = "Spot and On-Demand must not point to the same backing compute environment."
    }
  }
}
