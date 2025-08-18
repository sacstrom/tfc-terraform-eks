terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.51.0"
    }
  }

  backend "s3" {
    bucket = "sennco-mvp-terraform-eks"
    key    = "mvp-dev-dns/terraform.tfstate"
    region = "us-east-1"
  }

  required_version = ">= 1.3.6"
}
