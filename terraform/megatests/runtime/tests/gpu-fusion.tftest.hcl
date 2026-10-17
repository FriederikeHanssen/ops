mock_provider "seqera" {}
variables {
  deployment = {
    workspace_id   = "123"
    credentials_id = "test-credential"
    region         = "eu-west-1"
    work_dir       = "s3://example/test"
    name_prefix    = "test-variant"
    workload       = "gpu-fusion"
    spot = {
      queue_name     = "actual-variant-spot"
      head_queue     = "actual-ec2-head"
      execution_role = "arn:aws:iam::123456789012:role/execution"
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
      seqera_aws_batch_ce.cpu_fusion.config.enable_fusion == true &&
      seqera_aws_batch_ce.cpu_fusion.config.nvme_storage_enabled == true &&
      !seqera_aws_batch_ce.cpu_fusion.config.fusion_snapshots &&
      strcontains(seqera_aws_batch_ce.cpu_fusion.config.nextflow_config, "fusion {") == true
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
