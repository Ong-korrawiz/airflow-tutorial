import boto3
from pathlib import Path
from typing import Optional

from src.settings import S3_ACCESS_KEY_ID, S3_SECRET_ACCESS_KEY, S3_BUCKET_NAME, S3_BUCKET_REGION

def download_file_from_s3(
    s3_key: str,
    local_file_path: str | None = None,
    create_dirs: bool = True,
    bucket_name: str=S3_BUCKET_NAME,
) -> str:
    """
    Download a file from an S3 bucket to local storage.

    Args:
        s3_key: S3 object key to download
        bucket_name: Source S3 bucket
        local_file_path: Local path to save the file (defaults to filename from s3_key)
        create_dirs: Whether to create parent directories if they don't exist

    Returns:
        str: Path to the downloaded file
    """
    # If no local path specified, use the filename from s3_key
    if local_file_path is None:
        local_file_path = Path(s3_key).name
    
    local_file_path = Path(local_file_path)
    
    # Create parent directories if they don't exist
    if create_dirs and local_file_path.parent != Path('.'):
        local_file_path.parent.mkdir(parents=True, exist_ok=True)

    # Initialize S3 client
    s3 = boto3.client(
        "s3",
        aws_access_key_id=S3_ACCESS_KEY_ID,
        aws_secret_access_key=S3_SECRET_ACCESS_KEY,
        region_name=S3_BUCKET_REGION
    )
    
    # Download the file
    s3.download_file(
        Bucket=bucket_name,
        Key=s3_key,
        Filename=local_file_path.as_posix()
    )
    
    return local_file_path.as_posix()


def list_s3_objects(
    bucket_name: str,
    prefix: str = "",
    max_keys: int = 1000
) -> list[dict]:
    """
    List objects in an S3 bucket with optional prefix filtering.

    Args:
        bucket_name: S3 bucket name
        prefix: Object key prefix to filter by
        max_keys: Maximum number of objects to return

    Returns:
        list[dict]: List of S3 object metadata
    """
    s3 = boto3.client(
        "s3",
        aws_access_key_id=S3_ACCESS_KEY_ID,
        aws_secret_access_key=S3_SECRET_ACCESS_KEY,
        region_name=S3_BUCKET_REGION
    )
    
    response = s3.list_objects_v2(
        Bucket=bucket_name,
        Prefix=prefix,
        MaxKeys=max_keys
    )
    
    return response.get('Contents', [])


def get_s3_object_info(
    s3_key: str,
    bucket_name: str
) -> Optional[dict]:
    """
    Get metadata information about an S3 object.

    Args:
        s3_key: S3 object key
        bucket_name: S3 bucket name

    Returns:
        dict: Object metadata or None if object doesn't exist
    """
    s3 = boto3.client(
        "s3",
        aws_access_key_id=S3_ACCESS_KEY_ID,
        aws_secret_access_key=S3_SECRET_ACCESS_KEY,
        region_name=S3_BUCKET_REGION
    )
    
    try:
        response = s3.head_object(Bucket=bucket_name, Key=s3_key)
        return {
            'size': response['ContentLength'],
            'last_modified': response['LastModified'],
            'content_type': response['ContentType'],
            'metadata': response.get('Metadata', {}),
            'etag': response['ETag']
        }
    except s3.exceptions.NoSuchKey:
        return None
    except Exception as e:
        print(f"Error getting object info: {e}")
        return None


if __name__ == "__main__":
    # Example usage
    try:
        # Download a file
        downloaded_file = download_file_from_s3(
            s3_key="prophet-model/test.json",
            bucket_name=S3_BUCKET_NAME,
            local_file_path="downloads/test.json"
        )
        print(f"Downloaded file to: {downloaded_file}")
        
        # List objects with prefix
        objects = list_s3_objects(
            bucket_name=S3_BUCKET_NAME,
            prefix="prophet-model"
        )
        print(f"Found {len(objects)} objects with prefix 'prophet-model'")
        for obj in objects[:5]:  # Show first 5
            print(f"  - {obj['Key']} ({obj['Size']} bytes)")
        
        # Get object info
        info = get_s3_object_info(
            s3_key="prophet-model/test.json",
            bucket_name=S3_BUCKET_NAME
        )
        if info:
            print(f"Object info: {info}")
        else:
            print("Object not found")
            
    except Exception as e:
        print(f"Error: {e}")
