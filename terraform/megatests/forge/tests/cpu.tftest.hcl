mock_provider "seqera" {}
variables {
  workspace_id   = "123"
  credentials_id = "test-credential"
}
run "s3_staging_without_fusion" {
  command = plan
  variables {
    workload = "cpu-s3"
  }
  assert {
    condition = alltrue([
      for kind, ce in seqera_aws_batch_ce.carrier :
      !ce.config.enable_fusion && !ce.config.nvme_storage_enabled &&
      !ce.config.fusion_snapshots && !ce.config.forge.gpu_enabled &&
      !ce.config.forge.arm64_enabled && !ce.config.forge.fargate_head_enabled &&
      ce.name == "nf-core-test-cpu-s3-${kind}-forge" &&
      ce.config.work_dir == "s3://nf-core-awsmegatests/test/cpu-s3"
    ])
    error_message = "S3 staging must use its own names/path with Fusion, NVMe and snapshots disabled."
  }
}
run "gpu_fallback_retains_gpu_capacity" {
  command = plan
  variables {
    workload = "gpu-fusion"
  }
  assert {
    condition = alltrue([
      for ce in seqera_aws_batch_ce.carrier :
      ce.config.forge.gpu_enabled && !ce.config.forge.arm64_enabled &&
      ce.config.enable_fusion && ce.config.nvme_storage_enabled &&
      !ce.config.fusion_snapshots && ce.config.forge.max_cpus == 500 &&
      contains(ce.config.forge.instance_types, "g4dn") &&
      contains(ce.config.forge.instance_types, "g5")
    ])
    error_message = "Both GPU queues need NVIDIA-capable backing; mixed GPU models cannot safely enable snapshots."
  }
}
run "cpu_fusion_ec2_heads" {
  command = plan
  assert {
    condition = alltrue([
      for ce in seqera_aws_batch_ce.carrier :
      ce.config.enable_fusion && ce.config.enable_wave && ce.config.nvme_storage_enabled &&
      !ce.config.forge.fargate_head_enabled && !ce.config.forge.gpu_enabled &&
      !ce.config.forge.arm64_enabled && ce.config.forge.min_cpus == 0 &&
      ce.config.forge.max_cpus == 1000
    ])
    error_message = "The CPU Fusion workload must retain NVMe, EC2 heads and x86 CPU capacity."
  }
  assert {
    condition     = seqera_aws_batch_ce.carrier["spot"].config.forge.type == "SPOT" && seqera_aws_batch_ce.carrier["ondemand"].config.forge.type == "EC2"
    error_message = "Both capacity types are needed for fallback."
  }
  assert {
    condition     = seqera_aws_batch_ce.carrier["spot"].config.fusion_snapshots && !seqera_aws_batch_ce.carrier["ondemand"].config.fusion_snapshots
    error_message = "Enable snapshots on Spot only; On-Demand must keep snapshots disabled."
  }
  assert {
    condition     = seqera_aws_batch_ce.carrier["spot"].name == "nf-core-test-cpu-fusion-spot-forge" && seqera_aws_batch_ce.carrier["ondemand"].name == "nf-core-test-cpu-fusion-ondemand-forge"
    error_message = "Use test names rather than adopting production CEs."
  }
}
