"""Hugging Face hybrid provider: SDXL (text->image) then TripoSR (image->3D)."""
from __future__ import annotations

import io
import os
import tempfile
import zipfile
import uuid
import logging
from typing import Optional
import json

import requests

from ..config import HF_TOKEN, HF_SDXL_MODEL, HF_TRIPOSR_MODEL, MODEL_STORAGE_PATH

logger = logging.getLogger(__name__)


class HuggingFaceHybridProvider:
    """Provider that uses Hugging Face API to generate 3D models via SDXL + TripoSR."""
    
    def __init__(self):
        if not HF_TOKEN:
            raise RuntimeError("HF_TOKEN not configured. Set HF_TOKEN environment variable.")
        os.makedirs(MODEL_STORAGE_PATH, exist_ok=True)
        self.session = requests.Session()
        self.session.headers.update({
            "Authorization": f"Bearer {HF_TOKEN}",
        })
        logger.info(f"HuggingFaceHybridProvider initialized with models: {HF_SDXL_MODEL} -> {HF_TRIPOSR_MODEL}")

    def _wait_for_model_ready(self, url: str, max_retries: int = 10, wait_time: int = 5) -> None:
        """Wait for Hugging Face model to be ready if it's loading."""
        for _ in range(max_retries):
            try:
                resp = self.session.get(url.replace("/api-inference", ""), timeout=10)
                if resp.status_code == 200:
                    return
                elif resp.status_code == 503:
                    # Model is loading
                    logger.info(f"Model is loading, waiting {wait_time} seconds...")
                    import time
                    time.sleep(wait_time)
                else:
                    return
            except Exception:
                pass
        logger.warning(f"Model may still be loading after {max_retries * wait_time} seconds")

    def _sdxl_text_to_image(self, prompt: str) -> bytes:
        """Generate an image from text prompt using SDXL."""
        url = f"https://api-inference.huggingface.co/models/{HF_SDXL_MODEL}"
        
        logger.info(f"Generating image from prompt: {prompt[:50]}...")
        
        try:
            # Wait for model if needed
            self._wait_for_model_ready(url)
            
            resp = self.session.post(
                url, 
                json={
                    "inputs": prompt,
                    "parameters": {
                        "num_inference_steps": 30,
                        "guidance_scale": 7.5
                    }
                }, 
                timeout=180
            )
            
            # Handle model loading response
            if resp.status_code == 503:
                error_info = resp.json() if resp.content else {}
                estimated_time = error_info.get("estimated_time", 30)
                raise RuntimeError(
                    f"Model is loading. Estimated wait time: {estimated_time} seconds. "
                    f"Please try again in a moment."
                )
            
            resp.raise_for_status()
            
            # Check if response is JSON error
            try:
                error_json = resp.json()
                if "error" in error_json:
                    raise RuntimeError(f"SDXL API error: {error_json.get('error')}")
            except (json.JSONDecodeError, ValueError):
                pass  # Not JSON, assume it's image data
            
            logger.info("Image generated successfully")
            return resp.content  # image bytes (PNG)
            
        except requests.exceptions.Timeout:
            raise RuntimeError("SDXL model generation timed out. Please try again.")
        except requests.exceptions.RequestException as e:
            raise RuntimeError(f"SDXL API request failed: {str(e)}")

    def _triposr_image_to_glb(self, image_bytes: bytes, out_path: str) -> str:
        """Convert image to 3D model (GLB) using TripoSR."""
        url = f"https://api-inference.huggingface.co/models/{HF_TRIPOSR_MODEL}"
        
        logger.info("Converting image to 3D model...")
        
        try:
            # Wait for model if needed
            self._wait_for_model_ready(url)
            
            files = {"image": ("input.png", image_bytes, "image/png")}
            resp = self.session.post(url, files=files, timeout=600)
            
            # Handle model loading response
            if resp.status_code == 503:
                error_info = resp.json() if resp.content else {}
                estimated_time = error_info.get("estimated_time", 60)
                raise RuntimeError(
                    f"TripoSR model is loading. Estimated wait time: {estimated_time} seconds. "
                    f"Please try again in a moment."
                )
            
            resp.raise_for_status()

            # Check if response is JSON error
            try:
                error_json = resp.json()
                if "error" in error_json:
                    raise RuntimeError(f"TripoSR API error: {error_json.get('error')}")
            except (json.JSONDecodeError, ValueError):
                pass  # Not JSON, assume it's model data

            # Determine if response is zip or GLB
            ctype = resp.headers.get("content-type", "").lower()
            is_zip = "application/zip" in ctype or resp.content.startswith(b"PK\x03\x04")
            
            if is_zip:
                # Extract GLB from zip
                with zipfile.ZipFile(io.BytesIO(resp.content)) as zf:
                    # Find first .glb file
                    glb_name: Optional[str] = next(
                        (n for n in zf.namelist() if n.lower().endswith(".glb")), 
                        None
                    )
                    if not glb_name:
                        raise RuntimeError("TripoSR zip did not contain a .glb file")
                    
                    with zf.open(glb_name) as zglb, open(out_path, "wb") as f:
                        f.write(zglb.read())
            else:
                # Assume direct GLB
                with open(out_path, "wb") as f:
                    f.write(resp.content)
            
            # Verify file was created and has content
            if not os.path.exists(out_path) or os.path.getsize(out_path) == 0:
                raise RuntimeError("Generated GLB file is empty or was not created")
            
            logger.info(f"3D model generated successfully: {out_path} ({os.path.getsize(out_path)} bytes)")
            return out_path
            
        except requests.exceptions.Timeout:
            raise RuntimeError("TripoSR model generation timed out. Please try again.")
        except requests.exceptions.RequestException as e:
            raise RuntimeError(f"TripoSR API request failed: {str(e)}")

    def generate_glb(self, prompt: str) -> str:
        """Generate a GLB file from a text prompt.
        
        Args:
            prompt: Text description of the 3D model to generate
            
        Returns:
            Path to the generated GLB file
            
        Raises:
            RuntimeError: If generation fails at any step
        """
        try:
            # Generate unique model ID for this generation
            model_id = str(uuid.uuid4())
            
            # Create persistent directory for this model
            model_dir = os.path.join(MODEL_STORAGE_PATH, model_id)
            os.makedirs(model_dir, exist_ok=True)
            
            # Path for the final GLB file
            final_glb_path = os.path.join(model_dir, "model.glb")
            
            # Step 1: Generate image from text
            image_bytes = self._sdxl_text_to_image(prompt)
            
            # Step 2: Convert image to 3D model
            self._triposr_image_to_glb(image_bytes, final_glb_path)
            
            logger.info(f"Successfully generated model: {final_glb_path}")
            return final_glb_path
            
        except Exception as e:
            logger.error(f"Error generating model: {str(e)}")
            raise


