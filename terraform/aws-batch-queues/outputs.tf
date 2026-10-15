output "queue_contract" {
  description = "#220 contract v1: names for Platform/Nextflow, ARNs for AWS evidence and IAM. Forge resources remain externally owned."
  value = {
    for workload, queue in aws_batch_job_queue.spot : workload => {
      region                            = var.region
      spot_queue_name                   = queue.name
      spot_queue_arn                    = queue.arn
      spot_compute_environment_arns     = [for association in queue.compute_environment_order : association.compute_environment]
      ondemand_queue_name               = data.aws_batch_job_queue.ondemand[workload].name
      ondemand_queue_arn                = data.aws_batch_job_queue.ondemand[workload].arn
      ondemand_compute_environment_arns = [for association in data.aws_batch_job_queue.ondemand[workload].compute_environment_order : association.compute_environment]
      # Existing On-Demand CEs use the same EC2 queue for head and compute.
      head_queue_name = data.aws_batch_job_queue.ondemand[workload].name
      routing_config = templatefile("${path.module}/queue.config.tftpl", {
        spot_queue     = queue.name
        ondemand_queue = data.aws_batch_job_queue.ondemand[workload].name
      })
    }
  }
}
