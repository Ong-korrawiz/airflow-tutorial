from pathlib import Path

from dataclasses import dataclass




CONFIG_DIR = Path(__file__).parent

@dataclass
class ConfigPaths:
    CONFIG_DIR = Path(__file__).parent
    MODEL = str(CONFIG_DIR / "model_config.yml")
    DATA = str(CONFIG_DIR / "dataframe_config.yml")
    