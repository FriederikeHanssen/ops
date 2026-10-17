mock_provider "seqera" {}
variables {
  deployment = {
    workspace_id   = "123"
    credentials_id = "test-credential"
    region         = "eu-west-1"
    work_dir       = "s3://example/test"
    name_prefix    = "test-variant"
    workload       = "cpu-s3"
    spot = {
      queue_name     = "actual-variant-spot"
      head_queue     = "actual-ec2-head"
      execution_role = "arn:aws:iam::123456789012:role/execution"
      cli_path       = "/actual/forge/bin/aws"
    }
    ondemand = {
      queue_name = "actual-variant-ondemand"
      ce_id      = "od-id"
      ce_name    = "od-ce"
    }
  }
}
run "variant_manual_routing" {
  command = plan
  assert {
    condition = (
      seqera_aws_batch_ce.cpu_fusion.config.enable_fusion == false &&
      seqera_aws_batch_ce.cpu_fusion.config.nvme_storage_enabled == false &&
      !seqera_aws_batch_ce.cpu_fusion.config.fusion_snapshots &&
      seqera_aws_batch_ce.cpu_fusion.config.cli_path == "/actual/forge/bin/aws" &&
      strcontains(seqera_aws_batch_ce.cpu_fusion.config.nextflow_config, "fusion {") == false
    )
    error_message = "The runtime must preserve the discovered workload's storage and snapshot mode."
  }
  assert {
    condition = (
      seqera_aws_batch_ce.cpu_fusion.config.compute_queue == "actual-variant-spot" &&
      strcontains(seqera_aws_batch_ce.cpu_fusion.config.nextflow_config, "task.attempt > 1 ? 'actual-variant-ondemand' : 'actual-variant-spot'")
    )
    error_message = "Each variant must route to its own actual Spot and On-Demand queues."
  }
}
