from pathlib import Path
import pandas as pd
from sqlalchemy import create_engine, text

from logging import getLogger
from airflow.sdk import task
from airflow.utils.trigger_rule import TriggerRule


logger = getLogger(__name__)

@task(
        task_id="download_table_from_postgres",
        trigger_rule=TriggerRule.ONE_SUCCESS
        )
def download_table_from_postgres(
    table_name: str = "train",
    db_url: str | None = None,
) -> pd.DataFrame:
    """
    Download a table from Postgres and return it as a pandas DataFrame.

    Parameters:
    - table_name: name of the table to read (default "train")
    - db_url: SQLAlchemy database URL. If None, uses the same default as the upload script.

    Returns:
    - pandas.DataFrame with the table contents (parsing 'date' column as datetime if present)
    """
    # Default DB URL matches the upload script
    if db_url is None:
        db_url = "postgresql+psycopg2://airflow:airflow@postgres_dw:5433/airflow"

    engine = create_engine(db_url, future=True)

    sql = f"SELECT * FROM {table_name};"
    try:
        with engine.connect() as conn:
            # pd.read_sql can take a SQL string and a SQLAlchemy connection
            # parse_dates ensures the 'date' column (if present) is returned as datetime
            df = pd.read_sql(sql, conn, parse_dates=["date"])
    finally:
        # Dispose the engine to close any pooled connections
        engine.dispose()

    print(f"Table '{table_name}' downloaded successfully! Rows: {len(df)}")
    return df
    

@task(task_id="show_sample_data")
def show_sample_data(
    df: pd.DataFrame,
    num_rows: int = 5,
    **kwargs,
) -> None:
    """
    Display sample data from the DataFrame.

    Parameters:
    - df: pandas DataFrame to display samples from
    - num_rows: number of rows to display (default 5)
    """
    logger.info(f"Showing {num_rows} sample rows from the DataFrame:")
    logger.info(df.head(num_rows))