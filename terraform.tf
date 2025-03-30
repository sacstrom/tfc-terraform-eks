terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.51.0"
    }
  }

  backend "s3" {
    bucket = "bamboo02.smithmicro.net-terraform-state"
    key    = "mb-eks-cluster/terraform.tfstate"
    region = "eu-north-1"
  }

  required_version = ">= 1.3.6"
}
