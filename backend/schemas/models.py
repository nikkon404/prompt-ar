from pydantic import BaseModel


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
                "download_url": "/api/models/download/abc123-456def-789ghi"
            }
        }
