from __future__ import annotations

import logging
import os
import shutil
import uuid
from pathlib import Path
from gradio_client import Client
from gradio_client import exceptions as gradio_exceptions
import httpx


from config import (
    HF_TOKEN,
    MODEL_STORAGE_PATH,
)

logger = logging.getLogger(__name__)


class HuggingFaceService:
    """Handles 3D model generation via Hugging Face Spaces."""

    # ============================================================================
    # Initialization
    # ============================================================================

    def __init__(self):
        """Initializes all Gradio Clients."""
        if not HF_TOKEN:
            raise RuntimeError("HF_TOKEN not configured.")

        self.trellis_client: Client | None = None
        self.shap_e_client: Client | None = None

        # Ensure model storage directory exists
        self.storage_path = Path(MODEL_STORAGE_PATH)
        self.storage_path.mkdir(parents=True, exist_ok=True)

        # Initialize TRELLIS client
        try:
            self.trellis_client = Client(
                "dkatz2391/TRELLIS_TextTo3D_Try2", hf_token=HF_TOKEN
            )
            logger.info("✓ TRELLIS Gradio Client initialized")
        except Exception as e:
            logger.error(f"Failed to initialize TRELLIS Client: {e}")
            raise RuntimeError(f"Failed to initialize TRELLIS Client: {e}")

        # Initialize Shap-E client
        try:
            self.shap_e_client = Client("hysts/Shap-E", hf_token=HF_TOKEN)
            logger.info("✓ Shap-E Gradio Client initialized")
        except Exception as e:
            logger.warning(f"Failed to initialize Shap-E Client: {e}")
            logger.warning("Shap-E features will not be available")

    # ============================================================================
    # Public API - Model Generation
    # ============================================================================

    def text_to_3d(self, prompt: str, model_id: str | None = None) -> str:
        """Generate a 3D model directly from a text prompt using TRELLIS.

        Uses the /generate_and_extract_glb endpoint which:
        - Generates 3D model from text
        - Extracts GLB with textures
        - Returns GLB file path directly

        Args:
            prompt: Text prompt for 3D model generation
            model_id: Optional model ID to use for the filename. If not provided, generates a new UUID.

        Returns:
            Path to the generated GLB file
        """
        if not self.trellis_client:
            raise RuntimeError("TRELLIS Client not initialized.")

        logger.info(f"Generating 3D model from text prompt: '{prompt[:60]}...'")

        filename = model_id if model_id else str(uuid.uuid4())
        glb_path = self.storage_path / f"{filename}.glb"

        try:
            # TRELLIS API Endpoint Comparison:
            # - /generate_and_extract_glb: Returns GLB file directly with textures
            #   Includes mesh_simplify and texture_size parameters for AR optimization
            # - /text_to_3d: Basic endpoint, may return raw 3D data (needs testing)
            #   Missing mesh_simplify and texture_size parameters
            #
            # We use /generate_and_extract_glb because:
            # 1. Returns GLB file path/URL directly (no additional extraction step)
            # 2. Includes texture_size parameter (critical for texture export)
            # 3. Includes mesh_simplify parameter (optimizes for AR performance)
            # 4. One-step process - generates and extracts in single call
            logger.info("Generating 3D model with TRELLIS...")

            try:
                result = self.trellis_client.predict(
                    prompt=prompt,
                    seed=0,  # Fixed seed for reproducibility
                    ss_guidance_strength=7.5,
                    ss_sampling_steps=25,
                    slat_guidance_strength=7.5,
                    slat_sampling_steps=25,
                    mesh_simplify=0.95,  # Slight simplification for AR
                    texture_size=1024,  # Texture size - key for texture export!
                    api_name="/generate_and_extract_glb",  # Returns GLB directly
                )

                logger.debug(f"TRELLIS result type: {type(result)}")
                logger.debug(f"TRELLIS result: {result}")

            except gradio_exceptions.AppError as app_error:
                logger.error(f"TRELLIS AppError: {app_error}")
                raise RuntimeError(
                    f"TRELLIS Space returned an error: {app_error}. "
                    f"This might mean: 1) The Space is busy or has queue limits, "
                    f"2) The prompt is invalid, 3) The Space is experiencing issues."
                ) from app_error

            except Exception as api_error:
                logger.error(f"TRELLIS API call failed: {api_error}")
                import traceback

                logger.error(f"Full traceback: {traceback.format_exc()}")
                raise RuntimeError(
                    f"TRELLIS API call failed: {api_error}"
                ) from api_error

            # TRELLIS returns a string (file path or URL) directly
            if isinstance(result, str):
                glb_file_path = result
            elif isinstance(result, dict) and "value" in result:
                # Sometimes Gradio returns dict with 'value' key
                glb_file_path = result["value"]
            else:
                logger.error(
                    f"Unexpected TRELLIS result format: {type(result)}, value: {result}"
                )
                raise RuntimeError(f"Unexpected TRELLIS result format: {type(result)}")

            if not glb_file_path or not isinstance(glb_file_path, str):
                raise RuntimeError(
                    f"TRELLIS returned invalid file path: {glb_file_path}"
                )

            # TRELLIS may return a URL instead of a local file path
            if glb_file_path.startswith("http://") or glb_file_path.startswith(
                "https://"
            ):
                # Download the GLB file from the URL
                logger.info(f"TRELLIS returned URL, downloading GLB: {glb_file_path}")

                try:
                    with httpx.Client(timeout=60.0) as client:
                        response = client.get(glb_file_path)
                        response.raise_for_status()

                        # Ensure parent directory exists before saving
                        glb_path.parent.mkdir(parents=True, exist_ok=True)

                        # Save to our storage
                        with open(glb_path, "wb") as f:
                            f.write(response.content)

                        logger.info(
                            f"✓ Downloaded TRELLIS GLB: {glb_path} ({os.path.getsize(glb_path)} bytes)"
                        )
                except Exception as download_error:
                    logger.error(f"Failed to download GLB from URL: {download_error}")
                    raise RuntimeError(
                        f"Failed to download GLB from TRELLIS URL: {download_error}"
                    )
            else:
                # Local file path - check if it exists and copy it
                if not Path(glb_file_path).exists():
                    raise RuntimeError(
                        f"Generated GLB file not found: {glb_file_path}. "
                        f"TRELLIS may have failed to generate the model."
                    )

                # Ensure parent directory exists before copying
                glb_path.parent.mkdir(parents=True, exist_ok=True)

                # Copy the generated GLB to our storage
                shutil.copy(glb_file_path, glb_path)
                logger.info(
                    f"✓ TRELLIS GLB generated: {glb_path} ({os.path.getsize(glb_path)} bytes)"
                )

            return str(glb_path)

        except Exception as e:
            logger.error(f"TRELLIS text-to-3D generation failed: {e}")
            raise RuntimeError(f"3D model generation failed: {e}")

    def text_to_3d_shap_e(self, prompt: str, model_id: str | None = None) -> str:
        """Generate a 3D model from text prompt using Shap-E.

        Uses Shap-E for advanced 3D model generation from text prompts.
        Uses the /text_to_3d endpoint with the prompt parameter for text-to-3D.
        API Reference: https://huggingface.co/spaces/hysts/Shap-E

        Args:
            prompt: Text prompt for 3D model generation
            model_id: Optional model ID to use for the filename. If not provided, generates a new UUID.

        Returns:
            Path to the generated GLB file
        """
        if not self.shap_e_client:
            raise RuntimeError("Shap-E Client not initialized.")

        logger.info(
            f"Generating 3D model with Shap-E from text prompt: '{prompt[:60]}...'"
        )

        filename = model_id if model_id else str(uuid.uuid4())
        glb_path = self.storage_path / f"{filename}.glb"

        try:
            logger.info("Generating 3D model with Shap-E...")

            try:
                DEFAULT_SEED = 0
                DEFAULT_GUIDANCE_SCALE = 20.0
                DEFAULT_STEPS = 100
                # Shap-E /text-to-3d endpoint typically accepts:
                # - prompt (str)
                # - seed (int/float)
                # - guidance_scale (float)
                # - num_inference_steps (int) - not "steps"
                result = self.shap_e_client.predict(
                    prompt=prompt,
                    seed=DEFAULT_SEED,
                    guidance_scale=DEFAULT_GUIDANCE_SCALE,
                    num_inference_steps=DEFAULT_STEPS,  # This value is correctly mapped to 'num_inference_steps'
                    api_name="/text-to-3d",
                )

                logger.debug(f"Shap-E result type: {type(result)}")
                logger.debug(f"Shap-E result: {result}")

            except gradio_exceptions.AppError as app_error:
                logger.error(f"Shap-E AppError: {app_error}")
                raise RuntimeError(
                    f"Shap-E Space returned an error: {app_error}. "
                    f"This might mean: 1) The Space is busy or has queue limits, "
                    f"2) The prompt is invalid, 3) The Space is experiencing issues."
                ) from app_error

            except Exception as api_error:
                logger.error(f"Shap-E API call failed: {api_error}")
                import traceback

                logger.error(f"Full traceback: {traceback.format_exc()}")
                raise RuntimeError(
                    f"Shap-E API call failed: {api_error}"
                ) from api_error

            # Handle result - format depends on the actual endpoint response
            if isinstance(result, str):
                temp_file_path = result
            elif isinstance(result, (list, tuple)) and len(result) > 0:
                # Shap-E may return a tuple/list with file path as first element
                temp_file_path = result[0]
            elif isinstance(result, dict):
                # Check for common keys that might contain file path
                if "file" in result:
                    temp_file_path = result["file"]
                elif "value" in result:
                    temp_file_path = result["value"]
                else:
                    logger.error(
                        f"Unexpected Shap-E result format: {type(result)}, value: {result}"
                    )
                    raise RuntimeError(
                        f"Unexpected Shap-E result format: {type(result)}"
                    )
            else:
                logger.error(
                    f"Unexpected Shap-E result format: {type(result)}, value: {result}"
                )
                raise RuntimeError(f"Unexpected Shap-E result format: {type(result)}")

            if not temp_file_path or not isinstance(temp_file_path, str):
                raise RuntimeError(
                    f"Shap-E returned invalid file path: {temp_file_path}"
                )

            # Shap-E may return a URL instead of a local file path
            if temp_file_path.startswith("http://") or temp_file_path.startswith(
                "https://"
            ):
                # Download the GLB file from the URL
                logger.info(f"Shap-E returned URL, downloading GLB: {temp_file_path}")

                try:
                    with httpx.Client(timeout=120.0) as client:
                        response = client.get(temp_file_path)
                        response.raise_for_status()

                        # Ensure parent directory exists before saving
                        glb_path.parent.mkdir(parents=True, exist_ok=True)

                        # Save to our storage
                        with open(glb_path, "wb") as f:
                            f.write(response.content)

                        logger.info(
                            f"✓ Downloaded Shap-E GLB: {glb_path} ({os.path.getsize(glb_path)} bytes)"
                        )
                except Exception as download_error:
                    logger.error(f"Failed to download GLB from URL: {download_error}")
                    raise RuntimeError(
                        f"Failed to download GLB from Shap-E URL: {download_error}"
                    )
            else:
                # Local file path - check if it exists and copy it
                if not Path(temp_file_path).exists():
                    raise RuntimeError(
                        f"Generated GLB file not found: {temp_file_path}. "
                        f"Shap-E may have failed to generate the model."
                    )

                # Ensure parent directory exists before copying
                glb_path.parent.mkdir(parents=True, exist_ok=True)

                # Note: Shap-E might return a .ply, but we save it as .glb
                # as requested by the function signature.
                shutil.copy(temp_file_path, glb_path)
                logger.info(
                    f"✓ Shap-E GLB generated: {glb_path} ({os.path.getsize(glb_path)} bytes)"
                )

            return str(glb_path)

        except Exception as e:
            logger.error(f"Shap-E text-to-3D generation failed: {e}")
            raise RuntimeError(f"3D model generation failed: {e}")
