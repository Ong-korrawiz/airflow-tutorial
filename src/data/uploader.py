from pathlib import Path
import pandas as pd
from sqlalchemy import create_engine, text

from logging import getLogger

from airflow.sdk import task

logger = getLogger(__name__)

def is_table_exists(engine: create_engine, table_name: str) -> bool:
    """
    Check if a table exists in the database.

    Parameters:
        engine (create_engine): SQLAlchemy engine connected to the database.
        table_name (str): Name of the table to check.

    Returns:
        bool: True if the table exists, False otherwise.
    """
    logger.info(f"Checking if table '{table_name}' exists...")
    with engine.connect() as conn:
        result = conn.execute(
            text(
                "SELECT EXISTS ("
                "SELECT FROM information_schema.tables "
                "WHERE table_name = :table_name"
                ");"
            ),
            {"table_name": table_name},
        )
        exists = result.scalar()
    logger.info(f"Table '{table_name}' exists: {exists}")
    return exists

@task.branch(task_id="check_last_date")
def check_last_date():
    """
    Check the last date in the Postgres table.
    compare with the first date in the CSV to decide whether to upload or not.

    Returns:
        bool: True if new data is available, False otherwise.
    """

    ROOT_DIR = Path(__file__).parents[2]
    CSV_PATH = ROOT_DIR / "data/train.csv"  # your uploaded file path
    DB_URL = "postgresql+psycopg2://airflow:airflow@postgres_dw:5433/airflow"
    # DB_URL = "postgresql://airflow:airflow@localhost:5433/airflow"

    # check if csv file exists
    if not CSV_PATH.exists():
        logger.error(f"CSV file {CSV_PATH} does not exist.")
        raise FileNotFoundError(f"CSV file {CSV_PATH} does not exist.")

    TABLE_NAME = "train"
    engine = create_engine(DB_URL,future=True)

    # Get last date from Postgres
    with engine.connect() as conn:

        if not is_table_exists(engine, TABLE_NAME):
            logger.info(f"Table '{TABLE_NAME}' does not exist. New data available for upload.")
            return ["upload_csv_to_postgres"]

        result = conn.execute(text(f"SELECT MAX(date) FROM {TABLE_NAME};"))
        last_date_in_db = result.scalar()

    
    # Get first date from CSV
    df = pd.read_csv(CSV_PATH, parse_dates=["date"])
    first_date_in_csv = df['date'].min().date()

    # ensure dates are comparable by converting to date only
    logger.info(f"Last date in DB: {last_date_in_db}, First date in CSV: {first_date_in_csv}")
    # log type
    logger.debug(f"Type of last_date_in_db: {type(last_date_in_db)}, Type of first_date_in_csv: {type(first_date_in_csv)}")

    if last_date_in_db is None or first_date_in_csv > last_date_in_db:
        logger.info("New data available for upload.")
        return ["upload_csv_to_postgres"]
    else:
        logger.info("No new data to upload.")
        return ["download_table_from_postgres"]


@task(task_id="upload_csv_to_postgres")
def upload_csv_to_postgres(
    # db_url: str = DB_URL,
    # table_name: str = TABLE_NAME, 
):

    ROOT_DIR = Path(__file__).parents[2]
    CSV_PATH = ROOT_DIR / "data/train.csv"  # your uploaded file path
    DB_URL = "postgresql+psycopg2://airflow:airflow@postgres_dw:5433/airflow"
    # DB_URL = "postgresql://airflow:airflow@localhost:5433/airflow"

    TABLE_NAME = "train"
    engine = create_engine(DB_URL,future=True)
    
    # ---- STEP 1: Create table if it doesn't exist ----
    create_table_sql = f"""
    CREATE TABLE IF NOT EXISTS {TABLE_NAME} (
        date DATE,
        store INTEGER,
        item INTEGER,
        sales INTEGER
    );
    """
    with engine.connect() as conn:
        conn.execute(text(create_table_sql))
        conn.commit()
    
    # ---- STEP 2: Load CSV into dataframe ----
    df = pd.read_csv(CSV_PATH, parse_dates=["date"])
    
    # ---- STEP 3: Upload to Postgres ----
    df.to_sql(TABLE_NAME, engine, if_exists="append", index=False)
    
    logger.info("CSV uploaded successfully!")



@task(task_id="upload_forecasting_to_postgres")
def upload_forecasting_to_postgres(
    df: pd.DataFrame,
    table_name: str = "forecasting",
    db_url: str = "postgresql+psycopg2://airflow:airflow@postgres_dw:5433/airflow",
) -> None:
    """
    Upload forecasting DataFrame to Postgres.

    Parameters:
    - df: pandas DataFrame containing forecasting data
    - table_name: name of the target table in Postgres (default "forecasting")
    - db_url: SQLAlchemy database URL (default connects to local Postgres)
    """
    engine = create_engine(db_url, future=True)

    # Create table if it doesn't exist
    create_table_sql = f"""
    CREATE TABLE IF NOT EXISTS {table_name} (
        ds TIMESTAMP,
        yhat FLOAT,
        yhat_lower FLOAT,
        yhat_upper FLOAT
    );
    """
    with engine.connect() as conn:


        conn.execute(text(create_table_sql))
        conn.commit()

    # Upload DataFrame to Postgres
    df.to_sql(table_name, engine, if_exists="replace", index=False)

    logger.info(f"Forecasting data uploaded successfully to table '{table_name}'!")