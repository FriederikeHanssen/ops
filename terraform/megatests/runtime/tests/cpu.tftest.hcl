mock_provider "seqera" {}
variables {
  deployment = {
    workspace_id   = "123"
    credentials_id = "test-credential"
    region         = "eu-west-1"
    work_dir       = "s3://example/test"
    name_prefix    = "nf-core-test-cpu-fusion"
    spot = {
      queue_name     = "actual-forge-spot"
      head_queue     = "actual-ec2-head"
      execution_role = "arn:aws:iam::123456789012:role/execution"
    }
    ondemand = {
      queue_name = "actual-forge-ondemand"
      ce_id      = "od-id"
      ce_name    = "od-ce"
    }
  }
}
run "explicit_manual_routing" {
  command = plan
  assert {
    condition     = seqera_aws_batch_ce.cpu_fusion.config.compute_queue == "actual-forge-spot" && seqera_aws_batch_ce.cpu_fusion.config.head_queue == "actual-ec2-head"
    error_message = "Manual CE must consume the actual Forge compute and EC2 head queue names."
  }
  assert {
    condition     = strcontains(seqera_aws_batch_ce.cpu_fusion.config.nextflow_config, "task.attempt > 1 ? 'actual-forge-ondemand' : 'actual-forge-spot'") && !strcontains(seqera_aws_batch_ce.cpu_fusion.config.nextflow_config, "null")
    error_message = "Both routing branches must contain actual queue names."
  }
  assert {
    condition     = strcontains(seqera_aws_batch_ce.cpu_fusion.config.nextflow_config, "maxSpotAttempts = 5") && strcontains(seqera_aws_batch_ce.cpu_fusion.config.nextflow_config, "maxRetries = 2")
    error_message = "Do not redesign the existing retry policy."
  }
}
run "reject_identical_queues" {
  command = plan
  variables {
    deployment = {
      workspace_id   = "123"
      credentials_id = "test-credential"
      region         = "eu-west-1"
      work_dir       = "s3://example/test"
      name_prefix    = "nf-core-test-cpu-fusion"
      spot = {
        queue_name     = "same-queue"
        head_queue     = "actual-ec2-head"
        execution_role = "arn:aws:iam::123456789012:role/execution"
      }
      ondemand = {
        queue_name = "same-queue"
        ce_id      = "od-id"
        ce_name    = "od-ce"
      }
    }
  }
  expect_failures = [var.deployment]
}
