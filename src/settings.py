import os
from dotenv import load_dotenv

load_dotenv(".env")

S3_ACCESS_KEY_ID = os.getenv("S3_ACCESS_KEY_ID", "minioadmin")
S3_SECRET_ACCESS_KEY = os.getenv("S3_SECRET_ACCESS_KEY", "minioadmin")
S3_BUCKET_NAME = os.getenv("S3_BUCKET_NAME", "airflow-tutorial-bucket")
S3_BUCKET_REGION = os.getenv("S3_BUCKET_REGION", "us-east-1")