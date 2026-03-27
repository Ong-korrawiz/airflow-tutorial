resource "aws_ecs_cluster" "main" {
  name = "${var.project_name}-cluster"
}

resource "aws_security_group" "ecs_service_sg" {
  name        = "${var.project_name}-ecs-task-sg"
  vpc_id      = module.vpc.vpc_id

  # Allow all outbound traffic (so it can pull images and talk to RDS)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow the ALB to talk to the API server (Port 8080)
  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = [module.vpc.vpc_cidr_block]
  }
}

# Single Task Definition shared by services (overriding commands)
resource "aws_ecs_task_definition" "airflow_common" {
  family                   = "airflow-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.fargate_cpu
  memory                   = var.fargate_memory
  execution_role_arn       = aws_iam_role.ecs_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_task_role.arn

  container_definitions = jsonencode([
    {
      name  = "airflow"
      image = var.airflow_image
      environment = [
        { name = "AIRFLOW__DATABASE__SQL_ALCHEMY_CONN", value = "postgresql://airflow:airflow123@${aws_db_instance.airflow_db.endpoint}/airflow" },
        { name = "AIRFLOW__CORE__EXECUTOR", value = "LocalExecutor" } # Simpler for Free Tier
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = "/ecs/${var.project_name}"
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "airflow"
        }
      }
      mountPoints = [
        { sourceVolume = "efs-dags", containerPath = "/opt/airflow/dags" }
      ]
    }
  ])

  volume {
    name = "efs-dags"
    efs_volume_configuration {
      file_system_id          = aws_efs_file_system.airflow_efs.id
      transit_encryption      = "ENABLED"
      authorization_config {
        access_point_id = aws_efs_access_point.airflow_ap.id
        iam             = "ENABLED"
      }
    }
  }
}


