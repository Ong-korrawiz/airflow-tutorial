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