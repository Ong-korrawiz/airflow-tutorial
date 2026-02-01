from pathlib import Path
import yaml


def load_config_from_path(yml_path: str) -> dict:
    """
    Load configuration from a YAML file.

    Args:
        path (str): Path to the YAML config file.

    Returns:
        dict: Parsed config dictionary.

    Raises:
        FileNotFoundError: If the given file does not exist.
        yaml.YAMLError: If YAML parsing fails.
    """
    yml_path = Path(yml_path)

    if not yml_path.exists():
        raise FileNotFoundError(f"Config file not found: {yml_path}")

    with yml_path.open("r", encoding="utf-8") as file:
        config = yaml.safe_load(file)

    return config
