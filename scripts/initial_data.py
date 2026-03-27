from pathlib import Path
import pandas as pd
from sqlalchemy import create_engine, text

from logging import getLogger

logger = getLogger(__name__)



def upload_csv_to_postgres(
    # db_url: str = DB_URL,
    # table_name: str = TABLE_NAME, 
):

    ROOT_DIR = Path(__file__).parents[1]
    CSV_PATH = ROOT_DIR / "data/train.csv"  # your uploaded file path
    # DB_URL = "postgresql+psycopg2://airflow:airflow@localhost:5433/airflow"
    DB_URL = "postgresql://airflow:airflow@localhost:5433/airflow"

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
    print(f"Loaded CSV with {len(df)} rows and columns: {df.columns.tolist()}")
    
    # ---- STEP 3: Upload to Postgres ----
    df.to_sql(
        TABLE_NAME, 
        engine, 
        if_exists="append", 
        index=False
        )
    
    logger.info("CSV uploaded successfully!")

if __name__ == "__main__":
    upload_csv_to_postgres()