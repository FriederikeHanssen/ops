terraform {
  required_version = ">= 1.10.0"

  required_providers {
    seqera = {
      source  = "seqeralabs/seqera"
      version = "= 0.42.0"
    }
  }

  # CI supplies the bucket, key, region, and AWS OIDC role. State contains
  # Seqera IDs and must remain in the private CI-managed state bucket.
  backend "s3" {
    encrypt      = true
    use_lockfile = true
  }
}

provider "seqera" {}
