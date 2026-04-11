resource "aws_ecs_cluster" "main" {
  name = "${var.project_name}-cluster"
}


# --- Load Balancer for UI Access ---
resource "aws_lb" "airflow_alb" {
  name               = "${var.project_name}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = module.vpc.public_subnets
}


resource "aws_lb_target_group" "airflow_web_tg" {
  name        = "${var.project_name}-tg"
  port        = 8080
  protocol    = "HTTP"
  vpc_id      = module.vpc.vpc_id
  target_type = "ip"

  health_check {
    path = "/api/v2/monitor/health" # Airflow 3.0 health check endpoint
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.airflow_alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.airflow_web_tg.arn
  }
}

# --- ECS Service (The running webserver) ---
resource "aws_ecs_service" "airflow_webserver" {
  name            = "airflow-webserver"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.airflow_common.arn
  desired_count   = 1
  launch_type     = "FARGATE"
  enable_execute_command = true

  network_configuration {
    subnets         = module.vpc.private_subnets
    security_groups = [aws_security_group.ecs_service_sg.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.airflow_web_tg.arn
    container_name   = "airflow"
    container_port   = 8080
  }
}


resource "aws_security_group" "alb_sg" {
  name        = "${var.project_name}-alb-sg"
  description = "Allow HTTP inbound traffic to the ALB"
  vpc_id      = module.vpc.vpc_id

  # Allow inbound HTTP traffic from anywhere
  ingress {
    description      = "HTTP from internet"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  # Allow all outbound traffic (to reach ECS tasks)
  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
  }
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

  # NEW: Allow tasks to talk to VPC Endpoints (CloudWatch, ECR, etc.)
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [module.vpc.vpc_cidr_block]
  }

  ingress {
      from_port       = 8080
      to_port         = 8080
      protocol        = "tcp"
      security_groups = [aws_security_group.alb_sg.id] # Reference the new ALB SG
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
      command = ["api-server"] # Default command, can be overridden in service definition for workers/schedulers
      environment = [
        # Tell Airflow to dynamically trust the ALB's routing headers
        { name = "AIRFLOW__FAB__ENABLE_PROXY_FIX", value = "true" },
        { name = "AIRFLOW__CORE__AUTH_MANAGER", value = "airflow.providers.fab.auth_manager.fab_auth_manager.FabAuthManager" },
        { name = "AIRFLOW__API_AUTH__JWT_SECRET", value = "replace-this-with-a-random-secure-string" },
        # Trigger Database Migration on startup
        { name = "_AIRFLOW_DB_MIGRATE", value = "true" },
        { name = "AIRFLOW_HOME", value = "/opt/airflow" },

        # Trigger Admin User Creation
        { name = "AIRFLOW__DATABASE__SQL_ALCHEMY_CONN", value = var.airflow_database_sql_alchemy_conn },
        { name = "AIRFLOW__CORE__EXECUTOR", value = "LocalExecutor" }, # Simpler for Free Tier
        { name = "_AIRFLOW_WWW_USER_USERNAME", value = var.airflow_admin_username },
        { name = "_AIRFLOW_WWW_USER_PASSWORD", value = var.airflow_admin_password },
        { name = "_AIRFLOW_WWW_USER_CREATE", value = "true" },
        { name = "_AIRFLOW_WWW_USER_ROLE", value = var.airflow_role },
        { name = "_AIRFLOW_WWW_USER_EMAIL", value = var.airflow_user_email },
        { name = "_PIP_ADDITIONAL_REQUIREMENTS", value = "apache-airflow-providers-fab==2.0.2" }
      ]
# FIX: Added Port Mapping so the Load Balancer can find the container
      portMappings = [
        {
          containerPort = 8080
          hostPort      = 8080
          protocol      = "tcp"
        }
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



