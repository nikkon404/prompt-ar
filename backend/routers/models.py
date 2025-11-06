"""Router for model generation and download endpoints."""

import logging
import asyncio
from pathlib import Path
from fastapi import APIRouter, HTTPException
from fastapi.responses import Response

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
    """Download GLB model file with brightness normalization applied on download.

    This endpoint:
    1. Loads the GLB file
    2. Applies brightness normalization for AR visibility
    3. Returns the normalized GLB file as a single binary file

    Benefits:
    - Single file download (faster, simpler)
    - Smaller size (no zip overhead)
    - Brightness normalization applied on-demand (always uses latest settings)
    - Works directly with AR plugins (NodeType.fileSystemAppFolderGLB)
    """
    hf_service = get_hf_service()

    logger.info(f"Preparing GLB file for download (model ID: {model_id})")
    glb_path = Path(MODEL_STORAGE_PATH) / f"{model_id}.glb"

    # Check if GLB file exists
    if not glb_path.exists():
        logger.error(f"GLB file not found: {glb_path}")
        raise HTTPException(status_code=404, detail="Model file not found")

    try:
        # Apply brightness normalization to GLB file before serving
        logger.info("Applying brightness normalization to GLB file...")
        hf_service._normalize_materials_for_ar(glb_path)
        logger.info("✓ Brightness normalization applied to GLB")

        # Read normalized GLB file content
        with open(glb_path, "rb") as f:
            glb_content = f.read()

        logger.info(
            f"Serving normalized GLB file: {glb_path} ({len(glb_content)} bytes)"
        )

        # Return GLB file with proper headers
        return Response(
            content=glb_content,
            media_type="model/gltf-binary",
            headers={
                "Content-Type": "model/gltf-binary",
                "Content-Disposition": f'attachment; filename="{model_id}.glb"',
                "Access-Control-Allow-Origin": "*",
                "Access-Control-Allow-Methods": "GET, OPTIONS",
                "Access-Control-Allow-Headers": "*",
                "Cache-Control": "public, max-age=3600",
            },
        )
    except Exception as e:
        logger.error(f"Failed to prepare/serve GLB file: {e}")
        raise HTTPException(
            status_code=500, detail=f"Failed to prepare/serve GLB file: {str(e)}"
        )
