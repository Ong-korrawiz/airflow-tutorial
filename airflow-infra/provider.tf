terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    github = {
      source  = "integrations/github"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# Alias for resources that already exist in us-west-2
provider "aws" {
  alias  = "us_west_2"
  region = "us-west-2"
}

# GitHub provider reads GITHUB_TOKEN from environment variable
provider "github" {
  owner = var.github_username
  # token is read automatically from GITHUB_TOKEN environment variable
}
