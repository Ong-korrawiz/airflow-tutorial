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


provider "github" {
  token = var.github_token # You'll need a GitHub Personal Access Token
  owner = var.github_username
}
