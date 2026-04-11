# airflow-infra/data_storage.tf

# 1. Security Group for Private RDS
# Permission Check: We explicitly restrict ingress so ONLY ECS tasks can talk to this database.
resource "aws_security_group" "rds_sg" {
  name        = "${var.project_name}-rds-data-sg"
  description = "Allow PostgreSQL traffic strictly from Airflow ECS tasks"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description     = "PostgreSQL access from ECS tasks"
    from_port       = 5433
    to_port         = 5433
    protocol        = "tcp"
    # Network Check: This links directly to the ECS security group from your ecs.tf!
    security_groups = [aws_security_group.ecs_service_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# 2. DB Subnet Group
# Network Check: We explicitly map the database to the private subnets.
resource "aws_db_subnet_group" "rds_subnet_group" {
  name       = "${var.project_name}-rds-subnet-group"
  subnet_ids = module.vpc.private_subnets

  tags = {
    Name = "${var.project_name} Private DB Subnet Group"
  }
}

# 3. Private RDS Instance
resource "aws_db_instance" "private_postgres" {
  identifier             = "${var.project_name}-private-db"
  allocated_storage      = 20
  engine                 = "postgres"
  engine_version         = "16"
  instance_class         = "db.t3.micro" # Free-tier eligible 
  
  # The new target database name!
  db_name                = var.private_db_dbname
  
  # Reminder: You can move these to variables.tf for better security later!
  username               = var.private_db_username
  password               = var.private_db_password
  
  db_subnet_group_name   = aws_db_subnet_group.rds_subnet_group.name
  vpc_security_group_ids = [aws_security_group.rds_sg.id]
  
  # Security Check: Explicitly ensure it is NOT publicly accessible over the internet
  publicly_accessible    = false
  skip_final_snapshot    = true
  
  # 1. AWS Layer: Prevents deletion at the AWS API level
  deletion_protection    = true 

  # 2. Terraform Layer: Prevents Terraform from destroying the resource
  lifecycle {
    prevent_destroy = true
  }

}

# Output the endpoint so you can easily copy it into your Airflow Connections
output "private_rds_endpoint" {
  value       = aws_db_instance.private_postgres.endpoint
  description = "The connection endpoint for the private RDS instance"
}