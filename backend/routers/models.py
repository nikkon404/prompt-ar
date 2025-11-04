"""Router for model generation and download endpoints."""

import logging
from fastapi import APIRouter, HTTPException
from fastapi.responses import FileResponse

from ..schemas.models import PromptRequest, GenerationResponse
from ..services.model_service import ModelService
from ..services.storage_service import StorageService
from ..config import HF_TOKEN

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/api/models", tags=["Models"])

# Initialize services (in production, use dependency injection)
storage_service = StorageService()

# Initialize Hugging Face provider (required)
if not HF_TOKEN:
    raise RuntimeError(
        "HF_TOKEN is not configured. Set HF_TOKEN environment variable to enable model generation. "
        "Get your token from: https://huggingface.co/settings/tokens"
    )

try:
    from ..third_party.huggingface_provider import HuggingFaceHybridProvider

    provider = HuggingFaceHybridProvider()
    logger.info("Hugging Face provider initialized successfully")
except Exception as e:
    logger.error(f"Failed to initialize Hugging Face provider: {str(e)}")
    raise RuntimeError(
        f"Failed to initialize Hugging Face provider: {str(e)}. "
        "Please check your HF_TOKEN and ensure it's valid."
    ) from e

model_service = ModelService(storage_service, provider=provider)


@router.post("/generate", response_model=GenerationResponse)
async def generate_model(request: PromptRequest):
    """Generate a 3D model from a text prompt using Hugging Face hybrid approach.

    Uses SDXL (Stable Diffusion XL) for text-to-image generation,
    then TripoSR for image-to-3D model conversion (GLB format).

    The process:
    1. Text prompt → SDXL API → Image
    2. Image → TripoSR API → 3D Model (GLB)
    3. Model stored locally and served via download endpoint
    """
    logger.info(f"Received generation request for prompt: {request.prompt[:50]}...")

    try:
        model_id = await model_service.generate_model(request.prompt)

        download_url = f"/api/models/download/{model_id}"

        logger.info(f"Model generation completed successfully: {model_id}")

        return GenerationResponse(
            status="success",
            message="3D model generated successfully",
            model_id=model_id,
            download_url=download_url,
        )
    except ValueError as e:
        logger.warning(f"Validation error: {str(e)}")
        raise HTTPException(status_code=400, detail=str(e))
    except RuntimeError as e:
        # Handle errors from Hugging Face provider
        logger.error(f"Model generation error: {str(e)}")
        raise HTTPException(status_code=503, detail=str(e))
    except Exception as e:
        logger.error(
            f"Unexpected error during model generation: {str(e)}", exc_info=True
        )
        raise HTTPException(status_code=500, detail=f"Internal server error: {str(e)}")


@router.get("/download/{model_id}")
async def download_model(model_id: str):
    """Download a generated 3D model file.

    Returns the GLB file generated from the Hugging Face hybrid approach.
    """
    model_file_path = model_service.get_model_file_path(model_id)

    if not model_file_path:
        raise HTTPException(
            status_code=404,
            detail=f"Model not found or file missing. Model ID: {model_id}",
        )

    return FileResponse(
        path=model_file_path,
        media_type="model/gltf-binary",
        filename=f"model_{model_id}.glb",
        headers={"Content-Disposition": f"attachment; filename=model_{model_id}.glb"},
    )


@router.get("")
async def list_models():
    """List all generated models (for debugging purposes).

    Returns a list of all models that have been generated.
    """
    models = storage_service.get_all_models()

    # Add download URLs to each model
    for model_id, model_data in models.items():
        model_data["download_url"] = f"/api/models/download/{model_id}"

    return {"total": storage_service.get_models_count(), "models": models}


@router.get("/{model_id}")
async def get_model_info(model_id: str):
    """Get information about a specific model."""
    model = storage_service.get_model(model_id)

    if not model:
        raise HTTPException(status_code=404, detail="Model not found")

    model["download_url"] = f"/api/models/download/{model_id}"

    return model
