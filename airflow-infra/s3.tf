# --- S3 Bucket for Airflow Remote Logging ---
resource "aws_s3_bucket" "airflow_logs" {
  bucket        = "${var.project_name}-airflow-logs-bucket"
  force_destroy = true # Allows Terraform to delete the bucket even if it contains logs later
}

# Ensure the bucket is private
resource "aws_s3_bucket_public_access_block" "airflow_logs_public_access_block" {
  bucket = aws_s3_bucket.airflow_logs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}


# --- S3 Bucket for Forecasting Pipeline (Prophet Model) ---
resource "aws_s3_bucket" "forecasting_pipeline" {
  provider      = aws.us_west_2
  bucket        = "ong-forecasting-pipeline"
  force_destroy = true
}

resource "aws_s3_bucket_public_access_block" "forecasting_pipeline_public_access_block" {
  provider = aws.us_west_2
  bucket   = aws_s3_bucket.forecasting_pipeline.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Create the prophet-model/ prefix (folder)
resource "aws_s3_object" "prophet_model_prefix" {
  provider = aws.us_west_2
  bucket   = aws_s3_bucket.forecasting_pipeline.id
  key      = "prophet-model/"
  content  = ""
}

# Grant ECS tasks read/write access to this bucket
resource "aws_iam_role_policy" "airflow_forecasting_s3_policy" {
  name = "${var.project_name}-forecasting-s3-policy"
  role = aws_iam_role.ecs_task_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:DeleteObject",
          "s3:GetBucketLocation",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.forecasting_pipeline.arn,
          "${aws_s3_bucket.forecasting_pipeline.arn}/*"
        ]
      }
    ]
  })
}

