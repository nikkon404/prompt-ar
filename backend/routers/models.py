"""Router for model generation and download endpoints."""

import logging
import asyncio
from pathlib import Path
from fastapi import APIRouter, HTTPException
from fastapi.responses import FileResponse

from schemas.models import PromptRequest, GenerationResponse
from services.storage_service import StorageService

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/api/models", tags=["Models"])

# Initialize storage service
storage_service = StorageService()


def get_hf_service():
    """Get HuggingFaceService instance from main."""
    from main import hf_service

    if not hf_service:
        raise HTTPException(
            status_code=503,
            detail="HuggingFaceService not initialized. Check HF_TOKEN configuration.",
        )
    return hf_service


@router.post("/generate", response_model=GenerationResponse)
async def generate_model(request: PromptRequest):
    """Generate a 3D model from a text prompt using Shap-E.

    Flow: Text → Shap-E → 3D model (GLB format)
    """
    hf_service = get_hf_service()

    # Create model record
    model_id = storage_service.create_model_record(request.prompt)

    logger.info(
        f"Generating 3D model for prompt: '{request.prompt[:50]}...' (ID: {model_id})"
    )

    try:
        # Generate 3D model directly from text prompt
        glb_path = await asyncio.to_thread(hf_service.text_to_3d, request.prompt)
        logger.info(f"3D model generated: {glb_path}")

        # Update storage with model file
        storage_service.set_model_file(model_id, glb_path, fmt="glb")
        storage_service.update_model_status(model_id, "completed")

        logger.info(f"✓ 3D model generation completed for {model_id}")

        return GenerationResponse(
            status="success",
            message="3D model generated successfully",
            model_id=model_id,
            download_url=f"/api/models/download/{model_id}",
        )

    except RuntimeError as e:
        logger.error(f"Generation failed: {str(e)}")
        storage_service.update_model_status(model_id, "failed")
        raise HTTPException(status_code=503, detail=str(e))
    except Exception as e:
        logger.error(f"Unexpected error: {str(e)}", exc_info=True)
        storage_service.update_model_status(model_id, "failed")
        raise HTTPException(status_code=500, detail="Internal server error")


@router.get("/download/{model_id}")
async def download_model(model_id: str):
    """Download a generated 3D model file (GLB format)."""
    model = storage_service.get_model(model_id)

    if not model:
        raise HTTPException(status_code=404, detail="Model not found")

    if model["status"] != "completed":
        raise HTTPException(
            status_code=400,
            detail=f"Model generation status: {model['status']}. Model is not ready for download.",
        )

    file_path = model.get("file_path")
    if not file_path or not Path(file_path).exists():
        raise HTTPException(status_code=404, detail="Model file not found")

    logger.info(f"Serving model file: {file_path}")
    return FileResponse(
        path=file_path,
        media_type="model/gltf-binary",
        filename=f"{model_id}.glb",
    )
