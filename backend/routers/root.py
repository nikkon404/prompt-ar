"""Root router for API information and health checks."""
from fastapi import APIRouter

router = APIRouter(tags=["Root"])


@router.get("/")
async def root():
    """Root endpoint providing API information."""
    return {
        "message": "PromptAR Backend API",
        "version": "1.0.0",
        "endpoints": {
            "generate": "POST /api/models/generate",
            "download": "GET /api/models/download/{model_id}"
        }
    }


@router.get("/health")
async def health_check():
    """Health check endpoint."""
    return {
        "status": "healthy",
        "service": "PromptAR Backend"
    }
