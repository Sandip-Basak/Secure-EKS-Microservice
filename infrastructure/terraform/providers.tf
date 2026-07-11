terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  # Note: For production, you would configure an S3 backend with DynamoDB state locking here.
  # For this initialization stage, we will utilize local state.
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Environment = var.environment
      Project     = "MultiTenantMesh"
      ManagedBy   = "Terraform"
    }
  }
}