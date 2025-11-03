"""Application configuration."""
import os
from typing import List

# API Configuration
API_TITLE = "PromptAR Backend API"
API_VERSION = "1.0.0"
API_DESCRIPTION = "API for generating 3D models from text prompts and serving them for AR visualization"

# Server Configuration
HOST = os.getenv("HOST", "0.0.0.0")
PORT = int(os.getenv("PORT", 8000))

# CORS Configuration
ALLOWED_ORIGINS: List[str] = os.getenv(
    "ALLOWED_ORIGINS", 
    "*"  # In production, specify actual origins like ["http://localhost:3000", "https://yourapp.com"]
).split(",") if os.getenv("ALLOWED_ORIGINS") != "*" else ["*"]

# Model Configuration
MODEL_STORAGE_PATH = os.getenv("MODEL_STORAGE_PATH", "./models")
FAKE_MODEL_FILE = "fake_model.glb"

# Generation Configuration (for future use)
GENERATION_TIMEOUT = int(os.getenv("GENERATION_TIMEOUT", 300))  # 5 minutes
