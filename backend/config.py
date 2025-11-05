"""Application configuration.

Loads configuration from .env file.
Environment variables take precedence over .env file values.
"""

import os
from pathlib import Path
from typing import List

from dotenv import dotenv_values

# Load environment variables from .env file
# Look for .env file in the backend directory
env_path = Path(__file__).parent / ".env"
if env_path.exists():
    env_vars = dotenv_values(dotenv_path=env_path)
    print(f"Loaded configuration from {env_path}")
else:
    # Try loading from current directory as fallback
    env_vars = dotenv_values()
    print("Loaded configuration from .env file in current directory")


# Helper function to get config value (env vars override .env file)
def get_config(key: str, default: str = "") -> str:
    """Get configuration value from environment variable or .env file.

    Environment variables take precedence over .env file values.
    """
    return os.getenv(key, env_vars.get(key, default))


# API Configuration
API_TITLE = "PromptAR Backend API"
API_VERSION = "1.0.0"
API_DESCRIPTION = "API for generating 3D models from text prompts and serving them for AR visualization"

# Server Configuration
HOST = get_config("HOST", "0.0.0.0")
PORT = int(get_config("PORT", "8000"))

# CORS Configuration
allowed_origins_value = get_config("ALLOWED_ORIGINS", "*")
ALLOWED_ORIGINS: List[str] = (
    allowed_origins_value.split(",") if allowed_origins_value != "*" else ["*"]
)

# Model Configuration
MODEL_STORAGE_PATH = get_config("MODEL_STORAGE_PATH", "./models")

# Hugging Face Configuration (Required)
HF_TOKEN = get_config("HF_TOKEN", "")
if not HF_TOKEN:
    import warnings

    warnings.warn(
        "HF_TOKEN is not configured. Set HF_TOKEN in .env file or environment variable to enable model generation.",
        UserWarning,
    )

# 3D Model Generation Configuration (Free Gradio Space)
# Using Shap-E: https://huggingface.co/spaces/hysts/Shap-E
# Generates 3D models directly from text prompts (~5-10s)
# Uses OpenAI's Shap-E model - FREE but may have queue times on ZeroGPU
# You can override with a different Space ID in .env if needed
HF_TRIPOSR_SPACE_ID = "hysts/Shap-E"
