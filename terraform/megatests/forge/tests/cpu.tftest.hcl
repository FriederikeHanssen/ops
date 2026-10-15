mock_provider "seqera" {}
variables {
  workspace_id   = "123"
  credentials_id = "test-credential"
}
run "cpu_fusion_ec2_heads" {
  command = plan
  assert {
    condition = alltrue([
      for ce in seqera_aws_batch_ce.carrier :
      ce.config.enable_fusion && ce.config.enable_wave && ce.config.nvme_storage_enabled &&
      !ce.config.forge.fargate_head_enabled && !ce.config.forge.gpu_enabled &&
      !ce.config.forge.arm64_enabled && ce.config.forge.min_cpus == 0 &&
      ce.config.forge.max_cpus == 1000 && !ce.config.fusion_snapshots
    ])
    error_message = "First rollout must be CPU Fusion/NVMe with EC2 heads and no GPU/ARM/Snapshots."
  }
  assert {
    condition     = seqera_aws_batch_ce.carrier["spot"].config.forge.type == "SPOT" && seqera_aws_batch_ce.carrier["ondemand"].config.forge.type == "EC2"
    error_message = "Both capacity types are needed for fallback."
  }
  assert {
    condition     = seqera_aws_batch_ce.carrier["spot"].name == "nf-core-test-cpu-fusion-spot-forge" && seqera_aws_batch_ce.carrier["ondemand"].name == "nf-core-test-cpu-fusion-ondemand-forge"
    error_message = "Use test names rather than adopting production CEs."
  }
}
