# ECS Task Execution Role (System level)
resource "aws_iam_role" "ecs_execution_role" {
  name = "${var.project_name}-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "execution_policy" {
  role       = aws_iam_role.ecs_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# ECS Task Role (Application level - needed for EFS)
resource "aws_iam_role" "ecs_task_role" {
  name = "${var.project_name}-task-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
    }]
  })
}


# IAM user for GitHub Actions to push to ECR
resource "aws_iam_user" "github_actions" {
  name = "github-actions-deployer-${var.repo_name}"
}

resource "aws_iam_access_key" "github_actions" {
  user = aws_iam_user.github_actions.name
}

# Attach ECR push permissions
resource "aws_iam_user_policy_attachment" "ecr_policy" {
  user       = aws_iam_user.github_actions.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryFullAccess"
}


resource "aws_iam_role_policy_attachment" "task_efs_access" {
  role       = aws_iam_role.ecs_task_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonElasticFileSystemClientFullAccess"
}


# Add EFS permissions to the Execution Role so ECS can mount the volume
resource "aws_iam_role_policy_attachment" "execution_efs_access" {
  role       = aws_iam_role.ecs_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonElasticFileSystemClientFullAccess"
}


# --- IAM Policy for S3 Remote Logging ---
resource "aws_iam_role_policy" "airflow_s3_logs_policy" {
  name = "${var.project_name}-s3-logs-policy"
  role = aws_iam_role.ecs_task_role.id # This attaches to the task role used in your ecs.tf

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:GetBucketLocation",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.airflow_logs.arn,
          "${aws_s3_bucket.airflow_logs.arn}/*"
        ]
      }
    ]
  })
}