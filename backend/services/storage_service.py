"""Storage service for managing generated models."""
from typing import Dict, Optional
from datetime import datetime
import uuid


class StorageService:
    """In-memory storage service for generated models.
    
    In production, this would be replaced with a database like PostgreSQL or MongoDB.
    """
    
    def __init__(self):
        self._models: Dict[str, dict] = {}
    
    def create_model_record(self, prompt: str) -> str:
        """Create a new model record and return its ID."""
        model_id = str(uuid.uuid4())
        self._models[model_id] = {
            "model_id": model_id,
            "prompt": prompt,
            "created_at": datetime.now().isoformat(),
            "status": "processing",
            "file_path": None,
            "available_formats": []
        }
        return model_id
    
    def get_model(self, model_id: str) -> Optional[dict]:
        """Get a model by ID."""
        return self._models.get(model_id)
    
    def update_model_status(self, model_id: str, status: str):
        """Update the status of a model."""
        if model_id in self._models:
            self._models[model_id]["status"] = status

    def set_model_file(self, model_id: str, file_path: str, fmt: str = "glb"):
        """Set the file path and available format for a model."""
        if model_id in self._models:
            self._models[model_id]["file_path"] = file_path
            formats = set(self._models[model_id].get("available_formats", []))
            formats.add(fmt)
            self._models[model_id]["available_formats"] = list(formats)
    
    def get_all_models(self) -> Dict[str, dict]:
        """Get all stored models."""
        return self._models.copy()
    
    def get_models_count(self) -> int:
        """Get the total number of stored models."""
        return len(self._models)
