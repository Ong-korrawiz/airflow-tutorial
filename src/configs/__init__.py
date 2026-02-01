from src.configs.loader import load_config_from_path
from src.configs.config_paths import ConfigPaths

from src._types.configs_types import ModelConfigs, DataframeConfigs


def get_model_configs() -> ModelConfigs:
    loaded_model_configs = load_config_from_path(ConfigPaths.MODEL)
    return ModelConfigs(**loaded_model_configs)
    

def get_dataframe_configs() -> DataframeConfigs:
    loaded_dataframe_configs = load_config_from_path(ConfigPaths.DATA)
    return DataframeConfigs(**loaded_dataframe_configs)
    
