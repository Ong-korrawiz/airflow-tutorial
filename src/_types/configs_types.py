from dateutil.rrule import MONTHLY
from pydantic import BaseModel



class ModelConfigs(BaseModel):
    model_path: str
    forecasting_periods: int
    frequency: str = "D"



class DataframeConfigs(BaseModel):
    columns: list[str]