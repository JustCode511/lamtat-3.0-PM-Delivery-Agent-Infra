provider "aws" {
  region = var.aws_region

  # Every resource gets these tags automatically — handy for cost tracking and
  # for a clean `terraform destroy` after the demo.
  default_tags {
    tags = {
      Project   = "AABG-FY26"
      Component = "pm-agent"
      ManagedBy = "Terraform"
    }
  }
}
