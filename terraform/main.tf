terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Backend configuration will be passed via CLI in GitHub Actions
  # or via a backend.conf file locally.
  # backend "s3" {}
}

provider "aws" {
  region = var.aws_region
}
