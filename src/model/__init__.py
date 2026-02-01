from pathlib import Path

from datetime import timedelta
import pandas as pd
from functools import partial
from prophet import Prophet
from prophet.serialize import model_to_json, model_from_json
from airflow.sdk import task
from logging import getLogger
import json

from src import configs
from src.model.utils import check_dataframe
from src.s3.uploader import upload_json_to_s3
from src.s3.downloader import download_file_from_s3
from src.settings import S3_BUCKET_NAME, S3_ACCESS_KEY_ID, S3_SECRET_ACCESS_KEY

logger = getLogger(__name__)

def save_model(m: Prophet, filepath: str) -> None:
    import os
    print("AIRFLOW_UID", os.environ["AIRFLOW_UID"])
    print("AIRFLOW_GID", os.environ["AIRFLOW_GID"])
    # check if directory exists
    if not Path(filepath).parent.exists():
        logger.info(f"Creating directory for model at {Path(filepath).parent}...")
        Path(filepath).parent.mkdir(parents=True, exist_ok=True)

    # check if the file is writable
    if not os.access(str(Path(filepath).parent), os.W_OK):
        logger.error(f"File {filepath} is not writable.")
        raise PermissionError(f"File {filepath} is not writable.")

    logger.info(f"Saving model to {filepath}...")
    logger.info(f"S3 Bucket: {S3_BUCKET_NAME}, S3 Access Key ID: {S3_ACCESS_KEY_ID}, S3 Secret Access Key: {S3_SECRET_ACCESS_KEY}")
    # upload model to s3
    upload_json_to_s3(
        data=str(model_to_json(m)),
        s3_key=configs.get_model_configs().model_path,
    )


    logger.info("Model saved successfully.")

def load_model() -> Prophet:
    model_configs = configs.get_model_configs()
    filepath = model_configs.model_path
    download_file_from_s3(
        s3_key=filepath,
        local_file_path=filepath,
    )
    with open(filepath, 'r') as fin:
        logger.info(f"Loading model from {type(fin)}...")
        
        json_fin = json.load(fin)
        
        logger.info(f"Model JSON content type: {type(json_fin)}")
        m = model_from_json(json_fin)  # Load model
    return m

@task(task_id="validate_demand_dataframe")
def validate_demand_dataframe(df: pd.DataFrame) -> bool:
    """Validate if the provided DataFrame has the required columns for demand forecasting.
    Args:
        df (pd.DataFrame): DataFrame to validate.
        
    Returns:
        bool: True if the DataFrame has the required columns, False otherwise.
    """
    is_valid_df = check_dataframe(
        df=df,
        cols=configs.get_dataframe_configs().columns,
    )
    if not is_valid_df:
        raise ValueError(f"DataFrame is missing required columns: {configs.get_dataframe_configs().columns}")
        
    return True


@task(
        task_id="train_prophet_model",
        execution_timeout=timedelta(seconds=600),
        )
def train_prophet_model(train_df: pd.DataFrame, save: bool = True) -> Prophet:
    """Train a Prophet model on the provided training DataFrame.
    
    Args:
        train_df (pd.DataFrame): DataFrame containing training data with 'date' and '
            sales' columns.
        save (bool): Whether to save the trained model to disk. Defaults to True.
    """
    logger.info("Training Prophet model...")
    logger.debug(f"Training DataFrame head:\n{train_df.head()}")
    model = Prophet()
    prophet_df = train_df.rename(columns={'date': 'ds', 'sales': 'y'})
    model.fit(prophet_df)
    logger.info("Model training complete.")
    if save:
        logger.info("Saving trained model to disk...")
        model_configs = configs.get_model_configs()
        save_model(model, model_configs.model_path)
    return True
    

@task.branch(task_id="check_model_trained")
def is_model_trained() -> str:
    """Check if the Prophet model has been trained and saved to disk.
    
    Returns:
        str : task_id to load the model if it exists, otherwise train a new model.
    """
    # model_configs = configs.get_model_configs()
    try:
        _ = load_model()
        return "load_prophet_model"
    except FileNotFoundError:
        return "train_prophet_model"
    
    
@task(task_id="forecast_sales")
def forecast(
) -> pd.DataFrame:
    """Generate sales forecasts using a trained Prophet model.
    
    Args:
        current_df (pd.DataFrame): DataFrame containing current data with 'date' column.
        model (Prophet | None): Pre-trained Prophet model. If None, load from disk.
    
    Returns:
        pd.DataFrame: DataFrame containing forecasted sales with 'date' and 'forecasted_sales' columns.

    """
    # load model
    model = load_model()

    logger.info(f"Model loaded:\n {model}")

    model_configs = configs.get_model_configs()
    periods = model_configs.forecasting_periods
    freq = model_configs.frequency
    future = model.make_future_dataframe(periods=periods, freq=freq)
    forecast = model.predict(future)
    print("Forecasted result: ", forecast[['ds', 'yhat', 'yhat_lower', 'yhat_upper']].tail())
    return forecast