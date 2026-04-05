variable "aws_region" {
  description = "The AWS region to deploy to"
  default     = "us-east-1"
}

variable "project_name" {
  description = "Prefix for all resource names"
  default     = "airflow-3-dev"
}

variable "airflow_image" {
  description = "The URI of your Docker image in ECR"
  type        = string
}

# Free Tier Optimization: Minimum Fargate Specs
variable "fargate_cpu" { default = "512" }   # 0.5 vCPU
variable "fargate_memory" { default = "1024" } # 1 GB RAM


variable "github_token" {
  description = "GitHub Personal Access Token"
  type        = string
  sensitive   = true
}

variable "github_username" {
  description = "Your GitHub username or organization"
  type        = string
}

variable "repo_name" {
  description = "The name of your GitHub and ECR repository"
  type        = string
}

variable "airflow_admin_password" {
  description = "Admin password for Airflow UI"
  type        = string
  sensitive   = true
}

variable "airflow_admin_username" {
  description = "Admin username for Airflow UI"
  type        = string

}

variable "airflow_database_sql_alchemy_conn" {
  description = "SQL Alchemy connection string for Airflow"
  type        = string
}