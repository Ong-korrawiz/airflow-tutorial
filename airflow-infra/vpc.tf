module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "${var.project_name}-vpc"
  cidr = "10.0.0.0/16"

  azs             = ["${var.aws_region}a", "${var.aws_region}b"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24"]


  # --- Database Subnet Configuration ---
  # These define the specific IP ranges for your RDS instance
  database_subnets           = ["10.0.201.0/24", "10.0.202.0/24"]
  database_subnet_group_name = "${var.project_name}-db-subnet-group"
  create_database_subnet_group = true

  enable_nat_gateway = true
  single_nat_gateway = true # Keeps costs down for dev; use false for high-availability
}
