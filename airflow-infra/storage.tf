# Metadata DB Security Group
resource "aws_security_group" "db_sg" {
  name   = "${var.project_name}-db-sg"
  vpc_id = module.vpc.vpc_id

  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = [module.vpc.vpc_cidr_block]
  }
  ingress {
  from_port       = 5432
  to_port         = 5432
  protocol        = "tcp"
    security_groups = [aws_security_group.ecs_service_sg.id] # Allow ECS tasks to talk to DB
  }
}

resource "aws_security_group" "efs_sg" {
  name   = "${var.project_name}-efs-sg"
  vpc_id = module.vpc.vpc_id
  ingress {
    from_port   = 2049
    to_port     = 2049
    protocol    = "tcp"
    cidr_blocks = [module.vpc.vpc_cidr_block]
  }
}

# Metadata Database (RDS) - Free Tier Eligible
resource "aws_db_instance" "airflow_db" {
  identifier           = "${var.project_name}-metadata"
  engine               = "postgres"
  engine_version       = "15"
  instance_class       = "db.t3.micro" # Free Tier eligible
  allocated_storage    = 20            # Free Tier eligible
  db_name              = "airflow"
  username             = "airflow"
  password             = "airflow123"  # CHANGE THIS IN PROD
  db_subnet_group_name = module.vpc.database_subnet_group
  vpc_security_group_ids = [aws_security_group.db_sg.id]
  skip_final_snapshot  = true
  publicly_accessible  = false
}

# Shared Storage for DAGs
resource "aws_efs_file_system" "airflow_efs" {
  creation_token = "${var.project_name}-efs"
  encrypted      = true
}

resource "aws_efs_mount_target" "mount" {
  count           = length(module.vpc.private_subnets)
  file_system_id  = aws_efs_file_system.airflow_efs.id
  subnet_id       = module.vpc.private_subnets[count.index]
  security_groups = [aws_security_group.efs_sg.id]
}


# Add this to storage.tf
resource "aws_efs_access_point" "airflow_ap" {
  file_system_id = aws_efs_file_system.airflow_efs.id

  # This forces all files created to be owned by Airflow user (50000)
  posix_user {
    gid = 0
    uid = 50000
  }

  # This automatically creates the root directory if it doesn't exist
  root_directory {
    path = "/airflow"
    creation_info {
      owner_gid   = 0
      owner_uid   = 50000
      permissions = "775"
    }
  }
}
