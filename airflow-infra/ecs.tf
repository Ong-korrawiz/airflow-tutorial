resource "aws_ecs_cluster" "main" {
  name = "${var.project_name}-cluster"
}


# ============================================================================
# SHARED ENVIRONMENT VARIABLES (locals)
# ============================================================================
# These are the environment variables shared by ALL Airflow services.
# Service-specific vars are added in each task definition below.

locals {
  # Environment variables common to ALL Airflow 3.0 services
  airflow_common_env = [
    # --- Core Configuration ---
    { name = "AIRFLOW_HOME", value = "/opt/airflow" },
    { name = "AIRFLOW__CORE__AUTH_MANAGER", value = "airflow.providers.fab.auth_manager.fab_auth_manager.FabAuthManager" },
    { name = "AIRFLOW__CORE__EXECUTOR", value = "LocalExecutor" },
    { name = "AIRFLOW__CORE__DAGS_ARE_PAUSED_AT_CREATION", value = "true" },
    { name = "AIRFLOW__CORE__FERNET_KEY", value = var.fernet_key },
    { name = "AIRFLOW__CORE__HOSTNAME_CALLABLE", value = "airflow.utils.net.get_host_ip_address" },
    { name = "AIRFLOW__LOGGING__LOG_FETCH_HOSTNAME_CALLABLE", value = "airflow.utils.net.get_host_ip_address" },
    { name = "DB_URL", value = "postgresql+psycopg2://${var.private_db_username}:${var.private_db_password}@${aws_db_instance.private_postgres.endpoint}/${var.private_db_dbname}" },
    # Fix: Dockerfile sets PYTHONPATH=/opt/airflow/src but DAGs import `from src.data import ...`
    # which requires /opt/airflow to be in PYTHONPATH so Python finds /opt/airflow/src/data/...
    { name = "PYTHONPATH", value = "/opt/airflow:/opt/airflow/src" },

    # --- Airflow 3.0: Execution API Server URL ---
    # All services (scheduler, dag-processor, triggerer) MUST know how to reach the API server.
    # Cloud Map registers the api-server at: api-server.airflow.local
    { name = "AIRFLOW__CORE__EXECUTION_API_SERVER_URL", value = "http://api-server.airflow.local:8080/execution/" },

    # --- Database ---
    { name = "AIRFLOW__DATABASE__SQL_ALCHEMY_CONN", value = var.airflow_database_sql_alchemy_conn },

    # --- Auth / API ---
    { name = "AIRFLOW__API_AUTH__JWT_SECRET", value = var.jwt_secret },
    { name = "AIRFLOW__FAB__ENABLE_PROXY_FIX", value = "true" },

    # --- Logging: S3 Remote Logging ---
    { name = "AIRFLOW__LOGGING__REMOTE_LOGGING", value = "true" },
    { name = "AIRFLOW__LOGGING__REMOTE_BASE_LOG_FOLDER", value = "s3://${aws_s3_bucket.airflow_logs.bucket}/airflow-logs" },
    { name = "AIRFLOW__LOGGING__REMOTE_LOG_CONN_ID", value = "aws_default" },

    # --- Scheduler ---
    { name = "AIRFLOW__SCHEDULER__ENABLE_HEALTH_CHECK", value = "true" },

    # --- S3 Configuration (for model upload) ---
    { name = "S3_ACCESS_KEY_ID", value = var.s3_access_key_id },
    { name = "S3_SECRET_ACCESS_KEY", value = var.s3_secret_access_key },
    { name = "S3_BUCKET_NAME", value = var.s3_bucket_name },
    { name = "S3_BUCKET_REGION", value = var.s3_bucket_region },

    # --- Provider packages ---
    { name = "_PIP_ADDITIONAL_REQUIREMENTS", value = "apache-airflow-providers-fab==2.0.2" },
  ]

  # CloudWatch log configuration shared by all containers
  log_configuration = {
    logDriver = "awslogs"
    options = {
      "awslogs-group"         = "/ecs/${var.project_name}"
      "awslogs-region"        = var.aws_region
      "awslogs-stream-prefix" = "airflow"
    }
  }

  # DAGs are now baked into the Docker image (COPY dags/ /opt/airflow/dags/).
  # No EFS mount needed — mounting EFS here would overwrite the image's DAGs with an empty volume.
  mount_points = []
}


# ============================================================================
# TASK DEFINITIONS (one per Airflow service)
# ============================================================================
# ECS Services cannot override the command from a shared task definition,
# so we need a separate task definition for each Airflow component.

# --- 1. API Server Task Definition ---
resource "aws_ecs_task_definition" "airflow_apiserver" {
  family                   = "${var.project_name}-apiserver"
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
      command = ["api-server"]
      environment = concat(local.airflow_common_env, [
        # API server-only: DB migration and admin user creation on startup
        { name = "_AIRFLOW_DB_MIGRATE", value = "true" },
        { name = "_AIRFLOW_WWW_USER_CREATE", value = "true" },
        { name = "_AIRFLOW_WWW_USER_USERNAME", value = var.airflow_admin_username },
        { name = "_AIRFLOW_WWW_USER_PASSWORD", value = var.airflow_admin_password },
        { name = "_AIRFLOW_WWW_USER_ROLE", value = var.airflow_role },
        { name = "_AIRFLOW_WWW_USER_EMAIL", value = var.airflow_user_email },
      ])
      portMappings = [
        {
          containerPort = 8080
          hostPort      = 8080
          protocol      = "tcp"
        }
      ]
      logConfiguration = local.log_configuration
      mountPoints      = local.mount_points
    }
  ])


}


# --- 2. Scheduler Task Definition ---
resource "aws_ecs_task_definition" "airflow_scheduler" {
  family                   = "${var.project_name}-scheduler"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.fargate_cpu
  memory                   = var.fargate_memory
  execution_role_arn       = aws_iam_role.ecs_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_task_role.arn

  container_definitions = jsonencode([
    {
      name         = "airflow"
      image        = var.airflow_image
      command      = ["scheduler"]
      environment  = local.airflow_common_env
      logConfiguration = local.log_configuration
      mountPoints      = local.mount_points
    }
  ])

}


# --- 3. DAG Processor Task Definition ---
resource "aws_ecs_task_definition" "airflow_dag_processor" {
  family                   = "${var.project_name}-dag-processor"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.lightweight_cpu
  memory                   = var.lightweight_memory
  execution_role_arn       = aws_iam_role.ecs_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_task_role.arn

  container_definitions = jsonencode([
    {
      name         = "airflow"
      image        = var.airflow_image
      command      = ["dag-processor"]
      environment  = local.airflow_common_env
      logConfiguration = local.log_configuration
      mountPoints      = local.mount_points
    }
  ])

}


# --- 4. Triggerer Task Definition ---
resource "aws_ecs_task_definition" "airflow_triggerer" {
  family                   = "${var.project_name}-triggerer"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.lightweight_cpu
  memory                   = var.lightweight_memory
  execution_role_arn       = aws_iam_role.ecs_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_task_role.arn

  container_definitions = jsonencode([
    {
      name         = "airflow"
      image        = var.airflow_image
      command      = ["triggerer"]
      environment  = local.airflow_common_env
      logConfiguration = local.log_configuration
      mountPoints      = local.mount_points
    }
  ])


}


# ============================================================================
# LOAD BALANCER (for API Server / Web UI access)
# ============================================================================

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


# ============================================================================
# ECS SERVICES (one per Airflow component)
# ============================================================================

# --- 1. API Server Service ---
# Exposed via ALB for external access + registered in Cloud Map for internal discovery
resource "aws_ecs_service" "airflow_apiserver" {
  name            = "airflow-apiserver"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.airflow_apiserver.arn
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

  # Register in Cloud Map so other services can reach it at api-server.airflow.local
  service_registries {
    registry_arn = aws_service_discovery_service.api_server.arn
  }
}

# --- 2. Scheduler Service ---
resource "aws_ecs_service" "airflow_scheduler" {
  name            = "airflow-scheduler"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.airflow_scheduler.arn
  desired_count   = 1
  launch_type     = "FARGATE"
  enable_execute_command = true

  network_configuration {
    subnets         = module.vpc.private_subnets
    security_groups = [aws_security_group.ecs_service_sg.id]
    assign_public_ip = false
  }
}

# --- 3. DAG Processor Service ---
resource "aws_ecs_service" "airflow_dag_processor" {
  name            = "airflow-dag-processor"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.airflow_dag_processor.arn
  desired_count   = 1
  launch_type     = "FARGATE"
  enable_execute_command = true

  network_configuration {
    subnets         = module.vpc.private_subnets
    security_groups = [aws_security_group.ecs_service_sg.id]
    assign_public_ip = false
  }
}

# --- 4. Triggerer Service ---
resource "aws_ecs_service" "airflow_triggerer" {
  name            = "airflow-triggerer"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.airflow_triggerer.arn
  desired_count   = 1
  launch_type     = "FARGATE"
  enable_execute_command = true

  network_configuration {
    subnets         = module.vpc.private_subnets
    security_groups = [aws_security_group.ecs_service_sg.id]
    assign_public_ip = false
  }
}


# ============================================================================
# SECURITY GROUPS
# ============================================================================

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

  ingress {
      description = "Airflow Worker Live Logs"
      from_port   = 8793
      to_port     = 8793
      protocol    = "tcp"
      cidr_blocks = [module.vpc.vpc_cidr_block]
    }
}
