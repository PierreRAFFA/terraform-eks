provider "aws" {
  access_key = var.aws_access_key
  secret_key = var.aws_secret_key
  region = var.region

  default_tags {
    tags = {
      owner = "terraform"
    }
  }
}

terraform {
  backend "s3" {
    region = "eu-west-1"
    bucket = "pierreraffa"
    key    = "terraform.json"
  }
}

data "aws_caller_identity" "current" {}

locals {
  tags = {
    Company    = var.company_name
    Deployment = "Terraform"
  }
}