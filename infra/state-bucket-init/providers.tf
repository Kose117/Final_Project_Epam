terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Default provider: used for S3 and the rest of resources
provider "aws" {
  region = var.region
}