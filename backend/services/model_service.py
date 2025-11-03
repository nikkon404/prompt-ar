"""Model generation service for handling 3D model creation."""
import asyncio
import os
from typing import Optional
from datetime import datetime

from .storage_service import StorageService


class ModelService:
    """Service for generating and managing 3D models."""
    
    def __init__(self, storage_service: StorageService, fake_model_path: str = "fake_model.glb"):
        self.storage_service = storage_service
        self.fake_model_path = fake_model_path
    
    async def generate_model(self, prompt: str) -> str:
        """Generate a 3D model from a text prompt.
        
        Args:
            prompt: The text prompt describing the desired 3D model
            
        Returns:
            The model ID of the generated model
        """
        # Validate prompt
        if not prompt or len(prompt.strip()) == 0:
            raise ValueError("Prompt cannot be empty")
        
        # Create model record
        model_id = self.storage_service.create_model_record(prompt)
        
        # Simulate model generation (wait 5 seconds)
        await asyncio.sleep(5)
        
        # Update model status to completed
        self.storage_service.update_model_status(model_id, "completed")
        
        return model_id
    
    def get_model_file_path(self, model_id: str) -> Optional[str]:
        """Get the file path for a model, creating a fake file if needed.
        
        Args:
            model_id: The ID of the model
            
        Returns:
            The file path to the model, or None if model doesn't exist
        """
        # Check if model exists
        model = self.storage_service.get_model(model_id)
        if not model:
            return None
        
        # Ensure fake model file exists
        if not os.path.exists(self.fake_model_path):
            self._create_fake_model_file()
        
        return self.fake_model_path
    
    def _create_fake_model_file(self):
        """Create a fake GLB file for testing purposes."""
        with open(self.fake_model_path, "wb") as f:
            # This is just dummy binary data for testing
            # In production, this would be the actual generated .glb file
            f.write(b"FAKE_GLB_MODEL_DATA_FOR_TESTING")
