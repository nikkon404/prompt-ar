"""Router for model generation and download endpoints."""
from fastapi import APIRouter, HTTPException
from fastapi.responses import FileResponse

from ..schemas.models import PromptRequest, GenerationResponse
from ..services.model_service import ModelService
from ..services.storage_service import StorageService

router = APIRouter(prefix="/api/models", tags=["Models"])

# Initialize services (in production, use dependency injection)
storage_service = StorageService()
model_service = ModelService(storage_service)


@router.post("/generate", response_model=GenerationResponse)
async def generate_model(request: PromptRequest):
    """Generate a 3D model from a text prompt.
    
    Receives a prompt and starts 3D model generation.
    For now, waits 5 seconds and returns a fake URL.
    """
    try:
        model_id = await model_service.generate_model(request.prompt)
        
        download_url = f"/api/models/download/{model_id}"
        
        return GenerationResponse(
            status="success",
            message="3D model generated successfully",
            model_id=model_id,
            download_url=download_url
        )
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Internal server error: {str(e)}")


@router.get("/download/{model_id}")
async def download_model(model_id: str):
    """Download a generated 3D model file.
    
    Downloads the generated 3D model file.
    For now, returns a fake .glb file.
    """
    model_file_path = model_service.get_model_file_path(model_id)
    
    if not model_file_path:
        raise HTTPException(status_code=404, detail="Model not found")
    
    return FileResponse(
        path=model_file_path,
        media_type="model/gltf-binary",
        filename=f"model_{model_id}.glb",
        headers={
            "Content-Disposition": f"attachment; filename=model_{model_id}.glb"
        }
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
    
    return {
        "total": storage_service.get_models_count(),
        "models": models
    }


@router.get("/{model_id}")
async def get_model_info(model_id: str):
    """Get information about a specific model."""
    model = storage_service.get_model(model_id)
    
    if not model:
        raise HTTPException(status_code=404, detail="Model not found")
    
    model["download_url"] = f"/api/models/download/{model_id}"
    
    return model
