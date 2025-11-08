"""Router for model generation and download endpoints."""

import logging
import asyncio
import uuid
import tempfile
import shutil
from pathlib import Path
from fastapi import APIRouter, HTTPException, BackgroundTasks, File, UploadFile
from fastapi.responses import Response

from schemas.models import PromptRequest, GenerationResponse
from services.storage_service import StorageService
from services.ar_material_service import normalize_materials_for_ar
from config import MODEL_STORAGE_PATH

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/api/models", tags=["Models"])

# Initialize storage service
storage_service = StorageService()


def sanitize_error_message(error: Exception) -> str:
    """Sanitize error messages for frontend - hide technical details.

    Returns user-friendly error messages instead of exposing:
    - GPU quota details
    - Internal error messages
    - Technical stack traces
    """
    error_str = str(error).lower()

    # GPU quota errors
    if "gpu quota" in error_str or "exceeded" in error_str:
        return "The AI service is currently busy. Please try again in a few minutes."

    # Timeout errors
    if "timeout" in error_str or "timed out" in error_str:
        return "The request took too long. Please try again with a simpler prompt."

    # Space/service unavailable
    if "space" in error_str and ("sleeping" in error_str or "unavailable" in error_str):
        return "The AI service is temporarily unavailable. Please try again later."

    # Queue/busy errors
    if "queue" in error_str or "busy" in error_str:
        return "The service is busy. Please try again in a moment."

    # Network errors
    if "network" in error_str or "connection" in error_str:
        return "Network error occurred. Please check your connection and try again."

    # Generic fallback for other errors
    return "Model generation failed. Please try again or use a different prompt."


def get_hf_service():
    """Get HuggingFaceService instance from main module."""
    import sys

    # Try to get the main module - could be 'main' or '__main__' depending on how it was run
    main_module = None
    if "main" in sys.modules:
        main_module = sys.modules["main"]
    elif "__main__" in sys.modules:
        # When running as script, check if it's our main.py
        main_module = sys.modules["__main__"]

    # Fallback: import main module
    if not main_module:
        import main as main_module

    # Access hf_service dynamically from the module
    hf_service = getattr(main_module, "hf_service", None)

    if not hf_service:
        raise HTTPException(
            status_code=503,
            detail="HuggingFaceService not initialized. Check HF_TOKEN configuration.",
        )
    return hf_service


def cleanup_model_file(glb_path: Path):
    """Cleanup function to delete model file after download.

    This runs as a background task after the response is sent to the client.

    Args:
        glb_path: Path to the GLB file to delete
    """
    try:
        if glb_path.exists():
            glb_path.unlink()
            logger.info(f"✓ Deleted GLB file after download: {glb_path}")
        else:
            logger.warning(f"GLB file not found for deletion: {glb_path}")
    except Exception as delete_error:
        logger.warning(f"Failed to delete GLB file after download: {delete_error}")


@router.post("/generate", response_model=GenerationResponse)
async def generate_model(request: PromptRequest):
    """Generate a 3D model from a text prompt.

    Mode options:
    - "basic": Uses Shap-E for 3D model generation
    - "advanced": Uses TRELLIS for 3D model generation with textures

    Args:
        request: PromptRequest with prompt and mode ("basic" or "advanced")

    Returns:
        GenerationResponse with model_id and download_url
    """
    hf_service = get_hf_service()

    # Validate mode parameter
    mode = request.mode.lower() if request.mode else None
    if not mode or mode not in ["basic", "advanced"]:
        raise HTTPException(status_code=400, detail=f"Invalid mode: '{request.mode}'.")

    # Create model record
    model_id = storage_service.create_model_record(request.prompt)

    logger.info(
        f"Generating 3D model for prompt: '{request.prompt[:50]}...' "
        f"(ID: {model_id}, Mode: {mode})"
    )

    try:
        # Generate 3D model based on mode
        # Combine logic for Shap-E and TRELLIS generation
        hf_clients = {
            "basic": ("shap_e_client", hf_service.text_to_3d_shap_e, "Shap-E"),
            "advanced": ("trellis_client", hf_service.text_to_3d, "TRELLIS"),
        }

        client_attr, gen_func, mode_name = hf_clients[mode]

        if not getattr(hf_service, client_attr):
            raise HTTPException(
                status_code=503,
                detail=f"{mode_name} client not initialized. {mode_name} features are not available.",
            )

        logger.info(f"Using {mode_name} ({mode} mode) for generation...")
        glb_path = await asyncio.to_thread(gen_func, request.prompt, model_id)

        logger.info(f"3D model generated: {glb_path}")

        # Update storage with model file
        storage_service.set_model_file(model_id, glb_path, fmt="glb")
        storage_service.update_model_status(model_id, "completed")

        logger.info(f"✓ 3D model generation completed for {model_id} (mode: {mode})")

        resp = GenerationResponse(
            status="success",
            message=f"3D model generated successfully using {mode} mode",
            model_id=model_id,
            download_url=f"/api/models/download/{model_id}",
        )
        logger.info(f"Generation response: {resp}")
        return resp

    except HTTPException:
        # Re-raise HTTP exceptions as-is
        raise
    except RuntimeError as e:
        error_msg = str(e)
        logger.error(f"Generation failed: {error_msg}")
        storage_service.update_model_status(model_id, "failed")
        # Return sanitized error message to frontend
        user_friendly_msg = sanitize_error_message(e)
        raise HTTPException(status_code=503, detail=user_friendly_msg)
    except Exception as e:
        error_msg = str(e)
        logger.error(f"Unexpected error: {error_msg}", exc_info=True)
        storage_service.update_model_status(model_id, "failed")
        # Return sanitized error message to frontend
        user_friendly_msg = sanitize_error_message(e)
        raise HTTPException(status_code=500, detail=user_friendly_msg)


@router.get("/download/{model_id}")
async def download_model(model_id: str, background_tasks: BackgroundTasks):
    """Download GLB model file with brightness normalization applied on download.

    This endpoint:
    1. Loads the GLB file
    2. Applies brightness normalization for AR visibility
    3. Returns the normalized GLB file as a single binary file
    4. Deletes the file and clears memory after client downloads

    Benefits:
    - Single file download (faster, simpler)
    - Smaller size (no zip overhead)
    - Brightness normalization applied on-demand (always uses latest settings)
    - Works directly with AR plugins (NodeType.fileSystemAppFolderGLB)
    - Automatic cleanup after download (saves storage space)
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
        normalize_materials_for_ar(glb_path)
        logger.info("✓ Brightness normalization applied to GLB")

        # Read normalized GLB file content
        with open(glb_path, "rb") as f:
            glb_content = f.read()

        logger.info(
            f"Serving normalized GLB file: {glb_path} ({len(glb_content)} bytes)"
        )

        # Schedule cleanup task to run after response is sent
        background_tasks.add_task(cleanup_model_file, glb_path)

        # Create response
        response = Response(
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

        # Clear memory reference (will be garbage collected after response is sent)
        del glb_content

        return response
    except Exception as e:
        logger.error(f"Failed to prepare/serve GLB file: {e}")
        raise HTTPException(
            status_code=500, detail=f"Failed to prepare/serve GLB file: {str(e)}"
        )


@router.post("/generate-from-image", response_model=GenerationResponse)
async def generate_model_from_image(image: UploadFile = File(...)):
    """Generate a 3D model from an uploaded image using Hunyuan3D.

    This endpoint:
    1. Accepts an image file upload
    2. Uses Hunyuan3D to convert the image to a 3D GLB model with textures and colors
    3. Returns a model_id and download_url for the generated model

    Args:
        image: Uploaded image file (JPEG, PNG, etc.)

    Returns:
        GenerationResponse with model_id and download_url
    """
    hf_service = get_hf_service()

    if not hf_service.hunyuan_client:
        raise HTTPException(
            status_code=503,
            detail="Hunyuan3D-2 client not initialized. Hunyuan3D-2 is required for image-to-3D features.",
        )

    # Create model record with descriptive prompt
    model_id = storage_service.create_model_record(f"image_to_3d_{image.filename}")

    logger.info(f"Generating 3D model from image: {image.filename} (ID: {model_id})")

    # Create temporary directory for uploaded image
    temp_dir = Path(tempfile.gettempdir()) / "prompt_ar_uploads"
    temp_dir.mkdir(parents=True, exist_ok=True)

    # Save uploaded image to temporary file
    temp_image_path = temp_dir / f"{model_id}_{image.filename}"

    try:
        # Save uploaded file
        with open(temp_image_path, "wb") as buffer:
            shutil.copyfileobj(image.file, buffer)

        logger.info(f"Saved uploaded image to: {temp_image_path}")

        # Generate 3D model from image
        logger.info("Using Hunyuan3D-2 for image-to-3D generation...")
        glb_path = await asyncio.to_thread(
            hf_service.image_to_3d_hunyuan, str(temp_image_path), model_id
        )

        logger.info(f"3D model generated: {glb_path}")

        # Update storage with model file
        storage_service.set_model_file(model_id, glb_path, fmt="glb")
        storage_service.update_model_status(model_id, "completed")

        logger.info(f"✓ 3D model generation from image completed for {model_id}")

        resp = GenerationResponse(
            status="success",
            message="3D model generated successfully from image using Hunyuan3D-2",
            model_id=model_id,
            download_url=f"/api/models/download/{model_id}",
        )
        logger.info(f"Generation response: {resp}")
        return resp

    except HTTPException:
        # Re-raise HTTP exceptions as-is
        raise
    except RuntimeError as e:
        error_msg = str(e)
        logger.error(f"Generation from image failed: {error_msg}")
        storage_service.update_model_status(model_id, "failed")
        # Return sanitized error message to frontend
        user_friendly_msg = sanitize_error_message(e)
        raise HTTPException(status_code=503, detail=user_friendly_msg)
    except Exception as e:
        error_msg = str(e)
        logger.error(f"Unexpected error: {error_msg}", exc_info=True)
        storage_service.update_model_status(model_id, "failed")
        # Return sanitized error message to frontend
        user_friendly_msg = sanitize_error_message(e)
        raise HTTPException(status_code=500, detail=user_friendly_msg)
    finally:
        # Clean up temporary image file
        try:
            if temp_image_path.exists():
                temp_image_path.unlink()
                logger.debug(f"Cleaned up temporary image file: {temp_image_path}")
        except Exception as cleanup_error:
            logger.warning(f"Failed to cleanup temporary image file: {cleanup_error}")


@router.post("/generate-from-image2", response_model=GenerationResponse)
async def generate_model_from_image2(image: UploadFile = File(...)):
    """Generate a 3D model from an uploaded image using TRELLIS.

    This endpoint:
    1. Accepts an image file upload
    2. Uses TRELLIS 2 to convert the image to a 3D GLB model with textures and colors
    3. Returns a model_id and download_url for the generated model

    Args:
        image: Uploaded image file (JPEG, PNG, etc.)

    Returns:
        GenerationResponse with model_id and download_url
    """
    hf_service = get_hf_service()

    if not hf_service.trellis_client2:
        raise HTTPException(
            status_code=503,
            detail="TRELLIS 2  client not initialized. TRELLIS 2 is required for image-to-3D features.",
        )

    # Create model record with descriptive prompt
    model_id = storage_service.create_model_record(f"image_to_3d_{image.filename}")

    logger.info(f"Generating 3D model from image: {image.filename} (ID: {model_id})")

    # Create temporary directory for uploaded image
    temp_dir = Path(tempfile.gettempdir()) / "prompt_ar_uploads"
    temp_dir.mkdir(parents=True, exist_ok=True)

    # Save uploaded image to temporary file
    temp_image_path = temp_dir / f"{model_id}_{image.filename}"

    try:
        # Save uploaded file
        with open(temp_image_path, "wb") as buffer:
            shutil.copyfileobj(image.file, buffer)

        logger.info(f"Saved uploaded image to: {temp_image_path}")

        # Generate 3D model from image
        logger.info("Using TRELLIS 2 for image-to-3D generation...")
        glb_path = await asyncio.to_thread(
            hf_service.image_to_3d_TRELLIS, str(temp_image_path), model_id
        )

        logger.info(f"3D model generated: {glb_path}")

        # Update storage with model file
        storage_service.set_model_file(model_id, glb_path, fmt="glb")
        storage_service.update_model_status(model_id, "completed")

        logger.info(f"✓ 3D model generation from image completed for {model_id}")

        resp = GenerationResponse(
            status="success",
            message="3D model generated successfully from image using TRELLIS 2",
            model_id=model_id,
            download_url=f"/api/models/download/{model_id}",
        )
        logger.info(f"Generation response: {resp}")
        return resp

    except HTTPException:
        # Re-raise HTTP exceptions as-is
        raise
    except RuntimeError as e:
        error_msg = str(e)
        logger.error(f"Generation from image failed: {error_msg}")
        storage_service.update_model_status(model_id, "failed")
        # Return sanitized error message to frontend
        user_friendly_msg = sanitize_error_message(e)
        raise HTTPException(status_code=503, detail=user_friendly_msg)
    except Exception as e:
        error_msg = str(e)
        logger.error(f"Unexpected error: {error_msg}", exc_info=True)
        storage_service.update_model_status(model_id, "failed")
        # Return sanitized error message to frontend
        user_friendly_msg = sanitize_error_message(e)
        raise HTTPException(status_code=500, detail=user_friendly_msg)
    finally:
        # Clean up temporary image file
        try:
            if temp_image_path.exists():
                temp_image_path.unlink()
                logger.debug(f"Cleaned up temporary image file: {temp_image_path}")
        except Exception as cleanup_error:
            logger.warning(f"Failed to cleanup temporary image file: {cleanup_error}")
