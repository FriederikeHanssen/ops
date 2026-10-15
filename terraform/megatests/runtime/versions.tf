terraform {
  required_version = ">= 1.10.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "= 6.69.0"
    }
    seqera = {
      source  = "seqeralabs/seqera"
      version = "= 0.42.0"
    }
  }
  backend "s3" {
    use_lockfile = true
  }
}
provider "aws" {
  region              = var.deployment.region
  allowed_account_ids = [var.deployment.account_id]
}
provider "seqera" {}
