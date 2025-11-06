"""Router for model generation and download endpoints."""

import logging
import asyncio
from pathlib import Path
from fastapi import APIRouter, HTTPException
from fastapi.responses import FileResponse, Response

from schemas.models import PromptRequest, GenerationResponse
from services.storage_service import StorageService
from config import MODEL_STORAGE_PATH

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
    # model_id = "mesh_horse_1762378891721_enhanced"
    # model_id = "BoxTextured"

    logger.info(
        f"Generating 3D model for prompt: '{request.prompt[:50]}...' (ID: {model_id})"
    )

    try:
        # Generate 3D model directly from text prompt, passing model_id for filename
        glb_path = await asyncio.to_thread(
            hf_service.text_to_3d, request.prompt, model_id
        )
        logger.info(f"3D model generated: {glb_path}")

        # # # Update storage with model file
        storage_service.set_model_file(model_id, glb_path, fmt="glb")
        storage_service.update_model_status(model_id, "completed")

        logger.info(f"✓ 3D model generation completed for {model_id}")

        resp = GenerationResponse(
            status="success",
            message="3D model generated successfully",
            model_id=model_id,
            download_url=f"/api/models/download/{model_id}",
        )
        logger.info(f"Generation response: {resp}")
        return resp

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
    """Download a generated 3D model file (GLB format).

    Serves GLB files with proper CORS headers for AR web access.
    """
    logger.info(f"Downloading model file for model ID: {model_id}")
    file_path = Path(MODEL_STORAGE_PATH) / f"{model_id}.glb"

    # Check if model file exists
    if not file_path.exists():
        logger.error(f"Model file not found: {file_path}")
        raise HTTPException(status_code=404, detail="Model file not found")

    logger.info(f"Serving model file: {file_path}")

    # Read file content
    with open(str(file_path), "rb") as f:
        file_content = f.read()

    # Return with CORS headers for AR web access
    # Note: Our backend serves files directly (not through GitHub), so no ?raw=true needed
    # The file is served with proper CORS headers for AR web access
    return Response(
        content=file_content,
        media_type="model/gltf-binary",
        headers={
            # Don't use attachment - let browser handle it for AR
            "Content-Type": "model/gltf-binary",
            "Access-Control-Allow-Origin": "*",
            "Access-Control-Allow-Methods": "GET, OPTIONS",
            "Access-Control-Allow-Headers": "*",
            "Cache-Control": "public, max-age=3600",
        },
    )
