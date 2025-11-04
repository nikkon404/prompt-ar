"""Model generation service for handling 3D model creation."""

import asyncio
import os
import logging
from typing import Protocol

from .storage_service import StorageService

logger = logging.getLogger(__name__)


class _ModelProvider(Protocol):
    """Protocol for model generation providers."""

    def generate_glb(self, prompt: str) -> str:
        """Generate a GLB file from prompt and return local file path."""
        ...


class ModelService:
    """Service for generating and managing 3D models using Hugging Face hybrid approach."""

    def __init__(self, storage_service: StorageService, provider: _ModelProvider):
        if not provider:
            raise ValueError("Model provider is required. HF_TOKEN must be configured.")
        self.storage_service = storage_service
        self.provider = provider

    async def generate_model(self, prompt: str) -> str:
        """Generate a 3D model from a text prompt using Hugging Face API.

        Uses SDXL for text-to-image, then TripoSR for image-to-3D conversion.

        Args:
            prompt: The text prompt describing the desired 3D model

        Returns:
            The model ID of the generated model

        Raises:
            ValueError: If prompt is empty
            RuntimeError: If model generation fails
        """
        # Validate prompt
        if not prompt or len(prompt.strip()) == 0:
            raise ValueError("Prompt cannot be empty")

        # Create model record
        model_id = self.storage_service.create_model_record(prompt)

        try:
            # Run generation in a thread to avoid blocking the event loop
            logger.info(f"Starting model generation for prompt: {prompt[:50]}...")
            glb_path = await asyncio.to_thread(self.provider.generate_glb, prompt)

            # Verify the file was created
            if not os.path.exists(glb_path):
                raise RuntimeError(f"Generated model file not found at: {glb_path}")

            # Update storage with file path
            self.storage_service.set_model_file(model_id, glb_path, fmt="glb")
            self.storage_service.update_model_status(model_id, "completed")

            logger.info(f"Model generation completed successfully: {model_id}")
            return model_id

        except Exception as e:
            # Update status to failed
            self.storage_service.update_model_status(model_id, "failed")
            logger.error(f"Model generation failed for {model_id}: {str(e)}")
            raise RuntimeError(f"Failed to generate model: {str(e)}")

    def get_model_file_path(self, model_id: str) -> str | None:
        """Get the file path for a generated model.

        Args:
            model_id: The ID of the model

        Returns:
            The file path to the model, or None if model doesn't exist
        """
        # Check if model exists
        model = self.storage_service.get_model(model_id)
        if not model:
            return None

        # Get the file path from storage
        file_path = model.get("file_path")
        if file_path and os.path.exists(file_path):
            return file_path

        # Model record exists but file is missing
        logger.warning(
            f"Model {model_id} record exists but file not found at {file_path}"
        )
        return None
