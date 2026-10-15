terraform {
  required_version = ">= 1.10.0"

  required_providers {
    seqera = {
      source  = "seqeralabs/seqera"
      version = "= 0.42.0"
    }
  }

}

provider "seqera" {}
