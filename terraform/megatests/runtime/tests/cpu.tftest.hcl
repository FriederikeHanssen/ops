mock_provider "aws" {}
mock_provider "seqera" {}
variables {
  deployment = {
    workspace_id   = "123"
    credentials_id = "test-credential"
    account_id     = "123456789012"
    region         = "eu-west-1"
    work_dir       = "s3://example/test"
    name_prefix    = "nf-core-test-cpu-fusion"
    spot = {
      queue_name     = "actual-forge-spot"
      queue_arn      = "arn:aws:batch:eu-west-1:123456789012:job-queue/actual-forge-spot"
      head_queue     = "actual-ec2-head"
      execution_role = "arn:aws:iam::123456789012:role/execution"
    }
    ondemand = {
      queue_name = "actual-forge-ondemand"
      queue_arn  = "arn:aws:batch:eu-west-1:123456789012:job-queue/actual-forge-ondemand"
      ce_id      = "od-id"
      ce_name    = "od-ce"
    }
  }
}
override_data {
  target = data.aws_batch_job_queue.spot
  values = {
    arn                         = "arn:aws:batch:eu-west-1:123456789012:job-queue/actual-forge-spot"
    state                       = "ENABLED"
    status                      = "VALID"
    priority                    = 1
    scheduling_policy_arn       = null
    job_state_time_limit_action = []
    compute_environment_order = [{
      order               = 1
      compute_environment = "arn:aws:batch:eu-west-1:123456789012:compute-environment/actual-spot"
    }]
  }
}
override_data {
  target = data.aws_batch_job_queue.ondemand
  values = {
    arn    = "arn:aws:batch:eu-west-1:123456789012:job-queue/actual-forge-ondemand"
    state  = "ENABLED"
    status = "VALID"
    compute_environment_order = [{
      order               = 1
      compute_environment = "arn:aws:batch:eu-west-1:123456789012:compute-environment/actual-ondemand"
    }]
  }
}
run "explicit_manual_routing" {
  command = plan
  assert {
    condition     = seqera_aws_batch_ce.cpu_fusion.config.compute_queue == "nf-core-test-cpu-fusion-spot" && seqera_aws_batch_ce.cpu_fusion.config.head_queue == "actual-ec2-head"
    error_message = "Manual CE must consume the native queue output and actual EC2 head name."
  }
  assert {
    condition     = strcontains(seqera_aws_batch_ce.cpu_fusion.config.nextflow_config, "task.attempt > 1 ? 'actual-forge-ondemand' : 'nf-core-test-cpu-fusion-spot'") && !strcontains(seqera_aws_batch_ce.cpu_fusion.config.nextflow_config, "null")
    error_message = "Both routing branches must contain actual queue names."
  }
  assert {
    condition     = strcontains(seqera_aws_batch_ce.cpu_fusion.config.nextflow_config, "maxSpotAttempts = 5") && strcontains(seqera_aws_batch_ce.cpu_fusion.config.nextflow_config, "maxRetries = 2")
    error_message = "Do not redesign the existing retry policy."
  }
}
run "reject_unready_queue" {
  command = plan
  override_data {
    target = data.aws_batch_job_queue.ondemand
    values = {
      arn                       = "arn:aws:batch:eu-west-1:123456789012:job-queue/actual-forge-ondemand"
      state                     = "DISABLED"
      status                    = "VALID"
      compute_environment_order = [{ order = 1, compute_environment = "arn:aws:batch:eu-west-1:123456789012:compute-environment/actual-ondemand" }]
    }
  }
  expect_failures = [aws_batch_job_queue.spot]
}
run "reject_queue_identity_mismatch" {
  command = plan
  override_data {
    target = data.aws_batch_job_queue.ondemand
    values = {
      arn                       = "arn:aws:batch:eu-west-1:999999999999:job-queue/actual-forge-ondemand"
      state                     = "ENABLED"
      status                    = "VALID"
      compute_environment_order = [{ order = 1, compute_environment = "arn:aws:batch:eu-west-1:123456789012:compute-environment/actual-ondemand" }]
    }
  }
  expect_failures = [aws_batch_job_queue.spot]
}
