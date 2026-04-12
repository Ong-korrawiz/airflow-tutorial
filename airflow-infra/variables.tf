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
variable "fargate_cpu" { default = "1024" }   # Increased to 1 vCPU for better performance
variable "fargate_memory" { default = "2048" } # Increased to 2 GB RAM as recommended


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


variable "airflow_role" {
  description = "IAM role for Airflow tasks"
  type        = string

}

variable "airflow_user_email" {
  description = "Email address for the Airflow admin user"
  type        = string
}


variable "private_db_username" {
  description = "Username for the private RDS instance"
  type        = string
  
}

variable "private_db_password" {
  description = "Password for the private RDS instance"
  type        = string
  sensitive   = true
}


variable "private_db_dbname" {
  description = "Database name for the private RDS instance"
  type        = string
  
}

# --- Airflow 3.0 Multi-Service Variables ---

variable "fernet_key" {
  description = "Airflow Fernet key for encrypting connection passwords in the metadata DB"
  type        = string
  sensitive   = true
}

variable "jwt_secret" {
  description = "Secret key for Airflow API JWT authentication"
  type        = string
  sensitive   = true
}

# Scheduler uses the same sizing as the api-server (fargate_cpu / fargate_memory)
# Dag-processor and triggerer are lightweight and can use smaller specs
variable "lightweight_cpu" {
  description = "Fargate CPU units for lightweight services (dag-processor, triggerer)"
  default     = "256"
}

variable "lightweight_memory" {
  description = "Fargate memory (MB) for lightweight services (dag-processor, triggerer)"
  default     = "512"
}
