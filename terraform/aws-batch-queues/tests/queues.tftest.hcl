mock_provider "aws" {
  mock_data "aws_batch_compute_environment" {
    defaults = {
      state  = "ENABLED"
      status = "VALID"
    }
  }
}

variables {
  account_id = "123456789012"
  queues = {
    cpu = { spot = "cpu-source", ondemand = "cpu-ondemand" }
    gpu = { spot = "gpu-source", ondemand = "gpu-ondemand" }
  }
}

override_data {
  target = data.aws_batch_job_queue.spot["cpu"]
  values = {
    arn                         = "arn:aws:batch:eu-west-1:123456789012:job-queue/cpu-source"
    state                       = "ENABLED", status = "VALID", priority = 1
    scheduling_policy_arn       = null
    job_state_time_limit_action = []
    compute_environment_order   = [{ order = 1, compute_environment = "arn:aws:batch:eu-west-1:123456789012:compute-environment/cpu-spot" }]
  }
}

override_data {
  target = data.aws_batch_job_queue.spot["gpu"]
  values = {
    arn                         = "arn:aws:batch:eu-west-1:123456789012:job-queue/gpu-source"
    state                       = "ENABLED", status = "VALID", priority = 2
    scheduling_policy_arn       = null
    job_state_time_limit_action = [{ action = "CANCEL", max_time_seconds = 600, reason = "CAPACITY:INSUFFICIENT_INSTANCE_CAPACITY", state = "RUNNABLE" }]
    compute_environment_order   = [{ order = 1, compute_environment = "arn:aws:batch:eu-west-1:123456789012:compute-environment/gpu-spot" }]
  }
}

override_data {
  target = data.aws_batch_job_queue.ondemand["cpu"]
  values = {
    arn                       = "arn:aws:batch:eu-west-1:123456789012:job-queue/cpu-ondemand"
    state                     = "ENABLED", status = "VALID", priority = 1
    compute_environment_order = [{ order = 1, compute_environment = "arn:aws:batch:eu-west-1:123456789012:compute-environment/cpu-ondemand" }]
  }
}

override_data {
  target = data.aws_batch_job_queue.ondemand["gpu"]
  values = {
    arn                       = "arn:aws:batch:eu-west-1:123456789012:job-queue/gpu-ondemand"
    state                     = "ENABLED", status = "VALID", priority = 1
    compute_environment_order = [{ order = 1, compute_environment = "arn:aws:batch:eu-west-1:123456789012:compute-environment/gpu-ondemand" }]
  }
}

run "explicit_names_and_gpu_backing" {
  command = plan
  assert {
    condition     = output.queue_contract.cpu.spot_queue_name == "nf-core-megatests-pilot-cpu-spot" && output.queue_contract.cpu.ondemand_queue_name == "cpu-ondemand"
    error_message = "CPU routing must contain explicit source-derived names."
  }
  assert {
    condition     = output.queue_contract.gpu.spot_compute_environment_arns == ["arn:aws:batch:eu-west-1:123456789012:compute-environment/gpu-spot"] && output.queue_contract.gpu.ondemand_compute_environment_arns == ["arn:aws:batch:eu-west-1:123456789012:compute-environment/gpu-ondemand"]
    error_message = "GPU queues must preserve their own backing compute, including on fallback."
  }
  assert {
    condition     = strcontains(output.queue_contract.gpu.routing_config, "task.attempt > 1 ? 'gpu-ondemand' : 'nf-core-megatests-pilot-gpu-spot'") && !strcontains(output.queue_contract.gpu.routing_config, "null")
    error_message = "Both branches must be explicit with the existing attempt boundary."
  }
  assert {
    condition     = aws_batch_job_queue.spot["gpu"].priority == 2 && length(aws_batch_job_queue.spot["gpu"].job_state_time_limit_action) == 1
    error_message = "Preserve source scheduling priority and unschedulable-job action."
  }
}

run "reject_null_workaround" {
  command = plan
  variables {
    queues = {
      cpu = { spot = null, ondemand = "cpu-ondemand" }
      gpu = { spot = "gpu-source", ondemand = "gpu-ondemand" }
    }
  }
  expect_failures = [var.queues]
}

run "reject_shared_fallback" {
  command = plan
  variables {
    queues = {
      cpu = { spot = "cpu-source", ondemand = "cpu-ondemand" }
      gpu = { spot = "gpu-source", ondemand = "cpu-ondemand" }
    }
  }
  expect_failures = [var.queues]
}

run "reject_unavailable_queue" {
  command = plan
  override_data {
    target = data.aws_batch_job_queue.ondemand["gpu"]
    values = {
      arn                       = "arn:aws:batch:eu-west-1:123456789012:job-queue/gpu-ondemand"
      state                     = "DISABLED", status = "VALID", priority = 1
      compute_environment_order = [{ order = 1, compute_environment = "arn:aws:batch:eu-west-1:123456789012:compute-environment/gpu-ondemand" }]
    }
  }
  expect_failures = [aws_batch_job_queue.spot["gpu"]]
}

run "reject_invalid_backing_compute" {
  command = plan
  override_data {
    target = data.aws_batch_compute_environment.backing["arn:aws:batch:eu-west-1:123456789012:compute-environment/gpu-spot"]
    values = {
      state  = "ENABLED"
      status = "INVALID"
    }
  }
  expect_failures = [aws_batch_job_queue.spot["gpu"]]
}

run "reject_wrong_account" {
  command = plan
  override_data {
    target = data.aws_batch_job_queue.spot["cpu"]
    values = {
      arn                         = "arn:aws:batch:eu-west-1:999999999999:job-queue/cpu-source"
      state                       = "ENABLED"
      status                      = "VALID"
      priority                    = 1
      scheduling_policy_arn       = null
      job_state_time_limit_action = []
      compute_environment_order   = [{ order = 1, compute_environment = "arn:aws:batch:eu-west-1:123456789012:compute-environment/cpu-spot" }]
    }
  }
  expect_failures = [aws_batch_job_queue.spot["cpu"]]
}
