import pandas as pd
from functools import partial

from src import configs

def check_dataframe(df: pd.DataFrame, cols: list[str]) -> bool:
    """
    check if the DataFrame has sepecific columns:
    
    Args:
        df (pd.DataFrame): The DataFrame to check.
        cols (list[str]): The list of column names to check for.
        
    Returns:
        bool: True if all specified columns are present, False otherwise.
    """
    
    return all(col in df.columns for col in cols)


