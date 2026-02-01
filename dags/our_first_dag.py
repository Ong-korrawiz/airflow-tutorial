import os
import random
from datetime import datetime, timedelta

import pandas as pd
from airflow import DAG
from airflow.operators.empty import EmptyOperator
from airflow.operators.python import PythonOperator, BranchPythonOperator
from airflow.sdk import dag, task
from src.data import uploader, downloader
from src.model import (
    save_model,
    load_model,
    validate_demand_dataframe,
    train_prophet_model,
    is_model_trained,
    forecast,
)
from airflow.sdk import task, dag

default_args = {"owner": "your-name", "retries": 1, "retry_delay": timedelta(minutes=1)}


def generate_fake_events():
    events = [
        "Solar flare near Mars",
        "New AI model released",
        "Fusion milestone",
        "Celestial event tonight",
        "Economic policy update",
        "Storm in Nairobi",
    ]

    sample_events = random.sample(events, 5)
    data = {
        "timestamp": [
            datetime.now().strftime("%Y-%m-%d %H:%M:%S") for _ in sample_events
        ],
        "event": sample_events,
        "intensity_score": [round(random.uniform(1, 10), 2) for _ in sample_events],
        "category": [
            random.choice(["Science", "Tech", "Weather", "Space"])
            for _ in sample_events
        ],
    }

    df = pd.DataFrame(data)
    output_dir = "/opt/airflow/tmp"
    os.makedirs(output_dir, exist_ok=True)
    df.to_csv(f"{output_dir}/raw_events.csv", index=False)
    print(f"Generated {len(df)} events")


# def transform_data():
#     df = pd.read_csv('/opt/airflow/tmp/raw_events.csv')
#     df_sorted = df.sort_values(by="intensity_score", ascending=False)
#     df_sorted.to_csv('/opt/airflow/tmp/transformed_events.csv', index=False)
#     print(f"Transformed and sorted {len(df_sorted)} events")
with DAG(
    dag_id="daily_etl_pipeline",
    default_args=default_args,
    description="Daily ETL pipeline with transformation",
    start_date=datetime(2025, 1, 1),
    schedule="@daily",
    catchup=False,
) as dag:
    # branching operator to decide whether to upload new data
    dummy_first_task = EmptyOperator(task_id="start_pipeline")
    is_data_available = uploader.check_last_date()

    upload_task = uploader.upload_csv_to_postgres()
    table = downloader.download_table_from_postgres()
    validate_task = validate_demand_dataframe(df=table)

    # trained_flag = is_model_trained()

    # Call the task-decorated functions to get Task / XComArg objects
    train_task = train_prophet_model(train_df=table)
    # load_task = load_model()

    join = EmptyOperator(task_id="join_paths")

    # Forecast should depend on the loaded model (use the task result)
    forecasting_results = forecast()

    # upload forecasting results to Postgres
    upload_forecast_task = uploader.upload_forecasting_to_postgres(
        df=forecasting_results,
    )

    
    dummy_first_task >> is_data_available 
    is_data_available >> upload_task >> table
    is_data_available >> table    
    table >> validate_task >> train_task
    train_task >> forecasting_results
    forecasting_results >> upload_forecast_task