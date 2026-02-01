import boto3
from pathlib import Path
from typing import Dict, Any
import json
from logging import getLogger

from src.settings import S3_ACCESS_KEY_ID, S3_SECRET_ACCESS_KEY, S3_BUCKET_NAME, S3_BUCKET_REGION

logger = getLogger(__name__)

def upload_json_to_s3(
    data: Dict[str, Any],
    s3_key: str,
    bucket_name: str = S3_BUCKET_NAME,
    bucket_region: str = S3_BUCKET_REGION,
    permission: str = "private",
    content_type: str = "application/json"
) -> None:
    """
    Upload a local file to an S3 bucket.

    Args:
        file_path: Path to local file
        bucket_name: Target S3 bucket
        s3_key: S3 object key (defaults to filename)
    """

    # print("S3 KEY:", s3_key)

    s3 = boto3.client(
        "s3",
        aws_access_key_id=S3_ACCESS_KEY_ID,
        aws_secret_access_key=S3_SECRET_ACCESS_KEY,
        )
    # print("BUCKET NAME:", bucket_name)
    s3.put_object(
        Bucket=bucket_name,
        Key=s3_key,
        Body=json.dumps(data, ensure_ascii=False).encode("utf-8"),
    
        ContentType=content_type,
        ACL=permission,
        
    )
    logger.info(f"[/] Uploaded JSON data to s3://{bucket_name}/{s3_key}")



if __name__ == "__main__":
    # Example usage
    upload_json_to_s3(
        data={"Model": "Mock up model"},
        bucket_name=S3_BUCKET_NAME,
        s3_key="prophet-model/test.json",
    )