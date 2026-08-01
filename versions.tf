terraform {
  required_version = ">= 1.6"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.60"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }

  # State is local for the demo (gitignored). For team use, switch to an S3
  # backend + DynamoDB lock later — not needed for a single-operator demo.
}
