"""Hugging Face Service for 3D model generation using Shap-E."""

from __future__ import annotations

import logging
import os
import shutil
import uuid
from pathlib import Path
from gradio_client import Client

from config import (
    HF_TOKEN,
    HF_TRIPOSR_SPACE_ID,
    MODEL_STORAGE_PATH,
)

logger = logging.getLogger(__name__)


class HuggingFaceService:
    """Handles 3D model generation using Shap-E via Hugging Face Spaces."""

    def __init__(self):
        """Initializes the Shap-E Gradio Client."""
        if not HF_TOKEN:
            raise RuntimeError("HF_TOKEN not configured.")
        if not HF_TRIPOSR_SPACE_ID:
            raise RuntimeError(
                "HF_TRIPOSR_SPACE_ID not configured. Set it to use Shap-E for 3D generation."
            )

        self.triposr_client: Client | None = None

        # Ensure model storage directory exists
        self.storage_path = Path(MODEL_STORAGE_PATH)
        self.storage_path.mkdir(parents=True, exist_ok=True)

        # Initialize Shap-E client
        try:
            self.triposr_client = Client(HF_TRIPOSR_SPACE_ID, hf_token=HF_TOKEN)
            logger.info(f"✓ Shap-E Gradio Client initialized: {HF_TRIPOSR_SPACE_ID}")
        except Exception as e:
            logger.error(f"Failed to initialize Shap-E Gradio Client: {e}")
            raise RuntimeError(f"Failed to initialize Shap-E Client: {e}")

    def text_to_3d(self, prompt: str) -> str:
        """Generate a 3D model directly from a text prompt using Shap-E and return the GLB file path.

        This is faster than text→image→3d pipeline (~5-10s vs ~15-30s).
        Recommended for most use cases unless you need image control.
        """
        if not self.triposr_client:
            raise RuntimeError(
                "Shap-E Gradio Client not initialized. Set HF_TRIPOSR_SPACE_ID."
            )

        logger.info(f"Generating 3D model from text prompt: '{prompt[:60]}...'")

        try:
            # Shap-E text-to-3D endpoint
            # API: predict(prompt, seed, guidance_scale, num_inference_steps, api_name="/text-to-3d")
            # Returns: GLB file path (string)
            result = self.triposr_client.predict(
                prompt,
                0,  # seed (default: 0)
                15,  # guidance_scale (default: 15)
                75,  # num_inference_steps (default: 75)
                api_name="/text-to-3d",
            )

            # Result is a GLB file path (string)
            if isinstance(result, str):
                model_file = result
            elif isinstance(result, tuple) and len(result) >= 1:
                # Fallback: if it's a tuple, take the first element
                model_file = result[0]
            else:
                raise RuntimeError(
                    f"Unexpected result format from Shap-E: {type(result)}. Expected string or tuple."
                )

            # Copy the result file to our storage
            glb_path = self.storage_path / f"{uuid.uuid4()}.glb"

            if isinstance(model_file, str) and Path(model_file).exists():
                shutil.copy(model_file, glb_path)
                logger.info(
                    f"3D model generated: {glb_path} ({os.path.getsize(glb_path)} bytes)"
                )
                return str(glb_path)
            else:
                raise RuntimeError(
                    f"3D model file not found: {model_file}. "
                    f"Shap-E Space may have encountered an error."
                )

        except Exception as e:
            logger.error(f"Shap-E text-to-3D generation failed: {e}")
            raise RuntimeError(f"3D model generation failed: {e}")
