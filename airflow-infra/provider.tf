terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
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


provider "github" {
  token = var.github_token # You'll need a GitHub Personal Access Token
  owner = var.github_username
}
