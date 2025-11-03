from pydantic import BaseModel
from typing import Optional


class PromptRequest(BaseModel):
    """Request schema for model generation."""
    prompt: str

    class Config:
        json_schema_extra = {
            "example": {
                "prompt": "wooden chair"
            }
        }


class GenerationResponse(BaseModel):
    """Response schema for model generation."""
    status: str
    message: str
    model_id: str
    download_url: str

    class Config:
        json_schema_extra = {
            "example": {
                "status": "success",
                "message": "3D model generated successfully",
                "model_id": "abc123-456def-789ghi",
                "download_url": "/download/abc123-456def-789ghi"
            }
        }


class ModelInfo(BaseModel):
    """Information about a generated model."""
    model_id: str
    prompt: str
    created_at: str
    status: str
    download_url: Optional[str] = None

    class Config:
        json_schema_extra = {
            "example": {
                "model_id": "abc123-456def-789ghi",
                "prompt": "wooden chair",
                "created_at": "2024-01-15T10:30:00",
                "status": "completed",
                "download_url": "/download/abc123-456def-789ghi"
            }
        }
