from __future__ import annotations

import logging
import os
import shutil
import uuid
import time
from pathlib import Path
from gradio_client import Client, handle_file
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
        """Initializes all Gradio Clients.

        Note: HF_TOKEN is optional. If not provided, Spaces will use their own quota.
        If provided, authenticated calls may consume your GPU quota.
        """
        # HF_TOKEN is optional - we'll try without it first to avoid consuming your quota

        self.trellis_client: Client | None = None
        self.shap_e_client: Client | None = None
        self.hunyuan_client: Client | None = None
        self.trellis_client2: Client | None = None

        # Ensure model storage directory exists
        self.storage_path = Path(MODEL_STORAGE_PATH)
        self.storage_path.mkdir(parents=True, exist_ok=True)

        # Initialize TRELLIS client (non-blocking - text-to-3D features will be unavailable if this fails)
        # Hugging Face Spaces can be slow or sleeping (free tier), so we retry with backoff
        self.trellis_client = self._initialize_client_with_retry(
            "dkatz2391/TRELLIS_TextTo3D_Try2",
            "TRELLIS",
            max_retries=2,
        )

        # Initialize Shap-E client (non-blocking)
        self.shap_e_client = self._initialize_client_with_retry(
            "hysts/Shap-E",
            "Shap-E",
            max_retries=2,
        )

        # Initialize Hunyuan3D-2 client for image-to-3D (non-blocking)
        self.hunyuan_client = self._initialize_client_with_retry(
            "tencent/Hunyuan3D-2.1",
            "Hunyuan3D-2",
            max_retries=2,
        )
        self.trellis_client2 = self._initialize_client_with_retry(
            "trellis-community/TRELLIS",
            "TRELLIS-2",
            max_retries=2,
        )

    def _initialize_client_with_retry(
        self, space_id: str, service_name: str, max_retries: int = 2
    ) -> Client | None:
        """Initialize a Gradio Client with retry logic and exponential backoff.

        Hugging Face Spaces on the free tier can be slow to respond or sleeping,
        so we retry with increasing delays.

        Args:
            space_id: Hugging Face Space ID (e.g., "username/space-name")
            service_name: Human-readable name for logging
            max_retries: Maximum number of retry attempts

        Returns:
            Client instance if successful, None if all retries failed
        """
        for attempt in range(max_retries + 1):
            try:
                if attempt > 0:
                    # Exponential backoff: 5s, 10s
                    wait_time = 5 * (2 ** (attempt - 1))
                    logger.info(
                        f"Retrying {service_name} initialization (attempt {attempt + 1}/{max_retries + 1}) "
                        f"after {wait_time}s delay..."
                    )
                    time.sleep(wait_time)

                logger.info(
                    f"Initializing {service_name} Client (attempt {attempt + 1}/{max_retries + 1})..."
                )
                # Try without token first to avoid consuming your GPU quota
                # Most public Spaces work without authentication and use their own quota
                try:
                    client = Client(space_id)  # No token - uses Space owner's quota
                    logger.info(
                        f"✓ {service_name} Gradio Client initialized (no token - using Space owner's quota)"
                    )
                    return client
                except Exception as no_token_error:
                    # If that fails, try with token (may consume your GPU quota)
                    if HF_TOKEN:
                        logger.warning(
                            f"{service_name} requires authentication. Using HF_TOKEN (may consume your GPU quota)"
                        )
                        client = Client(space_id, hf_token=HF_TOKEN)
                        logger.info(
                            f"✓ {service_name} Gradio Client initialized (with token)"
                        )
                        return client
                    else:
                        # Re-raise the original error if no token available
                        raise no_token_error

            except Exception as e:
                error_msg = str(e).lower()
                is_timeout = "timeout" in error_msg or "timed out" in error_msg

                if attempt < max_retries:
                    logger.warning(
                        f"{service_name} initialization attempt {attempt + 1} failed: {e}. "
                        f"Will retry..."
                    )
                else:
                    # Final attempt failed
                    if is_timeout:
                        logger.warning(
                            f"Failed to initialize {service_name} Client after {max_retries + 1} attempts: {e}. "
                            f"This is likely because the Hugging Face Space is sleeping (free tier) or slow to respond. "
                            f"{service_name} features will not be available. "
                            f"The Space will wake up automatically when first used, but initialization may take longer."
                        )
                    else:
                        logger.warning(
                            f"Failed to initialize {service_name} Client after {max_retries + 1} attempts: {e}. "
                            f"{service_name} features will not be available."
                        )
                    return None

        return None

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

    def image_to_3d_hunyuan(
        self, image_file_path: str, model_id: str | None = None
    ) -> str:
        """
        Generate a 3D model from a 2D image using Hunyuan3D.

        This optimized version performs remote chaining of the /generation_all and
        /on_export_click steps to avoid slow local download/re-upload cycles of intermediary files.
        """
        if not self.hunyuan_client:
            raise RuntimeError("Hunyuan3D Client not initialized.")

        if not Path(image_file_path).exists():
            logger.error(f"Input image file not found at: {image_file_path}")
            raise FileNotFoundError(f"Input image file not found: {image_file_path}")

        logger.info(
            f"Generating 3D model with Hunyuan3D from image file: '{image_file_path}'"
        )

        filename = model_id if model_id else str(uuid.uuid4())
        glb_path = self.storage_path / f"{filename}.glb"

        # Default parameters - Tuned for faster generation time and to avoid GPU quota limits
        DEFAULT_STEPS = 15  # Further reduced from 20 to decrease generation time and avoid GPU quota limits (Job requested 180s vs 75s left)
        DEFAULT_GUIDANCE = 5.0
        DEFAULT_SEED = 1234
        RANDOMIZE_SEED = True
        DEFAULT_OCTREE_RES = 128  # Further reduced from 192 to decrease generation time and avoid GPU quota limits
        REMOVE_BG = True
        DEFAULT_NUM_CHUNKS = (
            4000  # Further reduced from 5000 to decrease generation time
        )

        # Helper function to extract file path, handling Gradio's inconsistent wrapping
        def extract_path(result_part):
            if isinstance(result_part, dict):
                # Check for 'value' (from previous API return) or 'path'/'name' (if pre-wrapped)
                if "value" in result_part:
                    return result_part["value"]
                if "path" in result_part:
                    return result_part["path"]
                if "name" in result_part:
                    return result_part["name"]
            return result_part

        # Helper function to wrap a remote path into the required dictionary format for the next API call
        # CRITICAL: Use 'path' as the key to satisfy the downstream Gradio component's FileData validation.
        def format_for_remote_api(path: str) -> dict:
            return {"path": path}

        try:
            # --- Step 1: Call /generation_all to get mesh and texture ---
            logger.info("Hunyuan3D Step 1/2: Calling /generation_all...")
            try:
                gen_result = self.hunyuan_client.predict(
                    image=handle_file(image_file_path),
                    mv_image_front=None,
                    mv_image_back=None,
                    mv_image_left=None,
                    mv_image_right=None,
                    steps=DEFAULT_STEPS,
                    guidance_scale=DEFAULT_GUIDANCE,
                    seed=DEFAULT_SEED,
                    octree_resolution=DEFAULT_OCTREE_RES,
                    check_box_rembg=REMOVE_BG,
                    num_chunks=DEFAULT_NUM_CHUNKS,
                    randomize_seed=RANDOMIZE_SEED,
                    api_name="/generation_all",
                )

                logger.debug(f"Hunyuan3D /generation_all result: {gen_result}")

            except gradio_exceptions.AppError as app_error:
                logger.error(f"Hunyuan3D /generation_all AppError: {app_error}")
                raise RuntimeError(
                    f"Hunyuan3D Space (generation) returned an error: {app_error}."
                ) from app_error
            except Exception as api_error:
                logger.error(f"Hunyuan3D /generation_all API call failed: {api_error}")
                import traceback

                logger.error(f"Full traceback: {traceback.format_exc()}")
                raise RuntimeError(
                    f"Hunyuan3D /generation_all API call failed: {api_error}"
                ) from api_error

            # /generation_all returns a tuple of 5 elements
            if not isinstance(gen_result, (list, tuple)) or len(gen_result) < 2:
                raise RuntimeError(
                    f"Unexpected result from Hunyuan3D /generation_all: {gen_result}"
                )

            # Extract raw remote paths (strings)
            mesh_raw_path = extract_path(gen_result[0])
            texture_raw_path = extract_path(gen_result[1])

            if not mesh_raw_path:
                raise RuntimeError(
                    f"Hunyuan3D /generation_all did not return a mesh file path."
                )

            logger.info(f"Hunyuan3D generated mesh: {mesh_raw_path}")
            logger.info(f"Hunyuan3D generated texture: {texture_raw_path}")

            # Check if /generation_all already returned a GLB file (rare, but possible)
            if isinstance(texture_raw_path, str) and texture_raw_path.endswith(".glb"):
                logger.info(
                    "Hunyuan3D /generation_all already returned a GLB file, skipping export step."
                )
                temp_file_path = texture_raw_path
            else:
                # --- Step 2: Call /on_export_click to convert to GLB (Remote Chaining) ---
                logger.info(
                    "Hunyuan3D Step 2/2: Calling /on_export_click to export GLB (Remote Chaining)..."
                )

                # Pass remote paths directly, formatted in the exact structure Gradio needs: {"path": path}.
                file_out_param = format_for_remote_api(mesh_raw_path)

                if texture_raw_path:
                    file_out2_param = format_for_remote_api(texture_raw_path)
                    export_texture_flag = True
                else:
                    # Use mesh for file_out2 if texture is missing
                    file_out2_param = format_for_remote_api(mesh_raw_path)
                    export_texture_flag = False
                    logger.info(
                        "No texture file generated, using mesh file for both file_out parameters"
                    )

                try:
                    export_result = self.hunyuan_client.predict(
                        file_out=file_out_param,  # Optimized: {"path": "/remote/path"}
                        file_out2=file_out2_param,  # Optimized: {"path": "/remote/path"}
                        file_type="glb",
                        reduce_face=False,
                        export_texture=export_texture_flag,
                        target_face_num=10000,
                        api_name="/on_export_click",
                    )

                    logger.debug(f"Hunyuan3D /on_export_click result: {export_result}")

                except gradio_exceptions.AppError as app_error:
                    logger.error(f"Hunyuan3D /on_export_click AppError: {app_error}")
                    raise RuntimeError(
                        f"Hunyuan3D Space (export) returned an error: {app_error}."
                    ) from app_error
                except Exception as api_error:
                    logger.error(
                        f"Hunyuan3D /on_export_click API call failed: {api_error}"
                    )

                    import traceback

                    logger.error(f"Full traceback: {traceback.format_exc()}")
                    raise RuntimeError(
                        f"Hunyuan3D /on_export_click API call failed: {api_error}"
                    ) from api_error

                # /on_export_click returns a tuple of 2 elements
                if (
                    not isinstance(export_result, (list, tuple))
                    or len(export_result) < 2
                ):
                    raise RuntimeError(
                        f"Unexpected result from Hunyuan3D /on_export_click: {export_result}"
                    )

                # Final result is the downloaded GLB URL/path
                temp_file_path = extract_path(export_result[1])

            if not temp_file_path or not isinstance(temp_file_path, str):
                raise RuntimeError(
                    f"Hunyuan3D /on_export_click returned invalid file path: {temp_file_path}"
                )

            # --- Step 3: Handle the final GLB file (download or copy) ---
            # The final GLB URL is the only file we need to download locally
            if temp_file_path.startswith("http://") or temp_file_path.startswith(
                "https://"
            ):
                logger.info(
                    f"Hunyuan3D returned URL, downloading GLB: {temp_file_path}"
                )
                try:
                    with httpx.Client(timeout=120.0) as client:
                        response = client.get(temp_file_path)
                        response.raise_for_status()

                        glb_path.parent.mkdir(parents=True, exist_ok=True)

                        with open(glb_path, "wb") as f:
                            f.write(response.content)
                        logger.info(
                            f"✓ Downloaded Hunyuan3D GLB: {glb_path} ({os.path.getsize(glb_path)} bytes)"
                        )
                except Exception as download_error:
                    logger.error(f"Failed to download GLB from URL: {download_error}")
                    raise RuntimeError(
                        f"Failed to download GLB from Hunyuan3D URL: {download_error}"
                    )
            else:
                if not Path(temp_file_path).exists():
                    raise RuntimeError(
                        f"Generated GLB file not found: {temp_file_path}. "
                    )

                glb_path.parent.mkdir(parents=True, exist_ok=True)

                shutil.copy(temp_file_path, glb_path)
                logger.info(
                    f"✓ Hunyuan3D GLB generated: {glb_path} ({os.path.getsize(glb_path)} bytes)"
                )

            return str(glb_path)

        except Exception as e:
            logger.error(f"Hunyuan3D image-to-3D generation failed: {e}")
            raise RuntimeError(f"3D model generation failed: {e}")

    def image_to_3d_TRELLIS(
        self, image_file_path: str, model_id: str | None = None
    ) -> str:
        """
        Generate a 3D model from a 2D image using the TRELLIS API endpoint.

        This function has been streamlined to use the single-step TRELLIS API
        endpoint (`/generate_and_extract_glb`) for faster, simpler generation,
        assuming the client (self.trellis_client2) is configured for the TRELLIS Space.

        Args:
            image_file_path: Local file path to the input 2D image.
            model_id: Optional model ID to use for the output filename.

        Returns:
            Path to the generated GLB file (local storage path).
        """
        # NOTE: Assuming self.trellis_client is now used for the TRELLIS-style generation.
        if not self.trellis_client2:
            raise RuntimeError(
                "3D Generation Client not initialized (using TRELLIS single-step API)."
            )

        input_path = Path(image_file_path)
        if not input_path.exists():
            logger.error(f"Input image file not found at: {image_file_path}")
            raise FileNotFoundError(f"Input image file not found: {image_file_path}")

        logger.info(
            f"Generating 3D model with TRELLIS (single-step) from image file: '{image_file_path}'"
        )

        filename = model_id if model_id else str(uuid.uuid4())
        glb_path = self.storage_path / f"{filename}.glb"

        # Helper function to extract file path, handling Gradio's inconsistent wrapping
        def extract_path(result_part):
            if isinstance(result_part, dict):
                if "value" in result_part:
                    return result_part["value"]
                if "path" in result_part:
                    return result_part["path"]
                if "name" in result_part:
                    return result_part["name"]
            return result_part

        try:
            # --- Step 1: Call /generate_and_extract_glb (TRELLIS single-step API) ---
            logger.info("TRELLIS Step 1/1: Calling /generate_and_extract_glb...")

            # Parameters derived from the TRELLIS Gradio API example
            # Using self.trellis_client2 as the client for this operation
            gen_result = self.trellis_client2.predict(
                image=handle_file(image_file_path),
                multiimages=[],
                seed=0,
                ss_guidance_strength=7.5,
                ss_sampling_steps=12,
                slat_guidance_strength=3,
                slat_sampling_steps=12,
                multiimage_algo="stochastic",
                mesh_simplify=0.95,
                texture_size=1024,
                api_name="/generate_and_extract_glb",
            )

            logger.debug(f"TRELLIS /generate_and_extract_glb result: {gen_result}")

            if not isinstance(gen_result, (list, tuple)) or not gen_result:
                raise RuntimeError(
                    f"Unexpected result from TRELLIS /generate_and_extract_glb: {gen_result}"
                )

            # The TRELLIS endpoint returns a tuple of 3 elements: [video, glb/gaussian, download_glb]
            # The second element (index [1]) is the file path for the Litmodel3d component (glb/gaussian).
            # We check the first element ([0]) which is the video component, as it often contains the file path first.

            # The TRELLIS API documentation shows the video component (index 0) is the first return element.
            # We need the path to the downloaded GLB file. Let's assume the first element path or the second element path.
            # Based on the API doc:
            # Returns tuple of 3 elements:
            # [0] dict(video: filepath, subtitles: filepath | None) -> The Video component path
            # [1] filepath -> The Litmodel3d component path (GLB/Gaussian)
            # [2] filepath -> The Downloadbutton path (GLB)

            # The most reliable path to the output file is often the second element [1] or third [2],
            # but the original TRELLIS function used [0]. We will update to use [1] for the Litmodel3d path
            # as it is more likely to contain the actual GLB data path when running remotely.

            # Let's use index [1] or [2] if available, falling back to [0].
            temp_file_path = (
                extract_path(gen_result[1]) if len(gen_result) > 1 else None
            )

            if not temp_file_path:
                temp_file_path = extract_path(gen_result[0])

            if not temp_file_path or not isinstance(temp_file_path, str):
                raise RuntimeError(
                    f"TRELLIS returned invalid file path: {temp_file_path}"
                )

            # --- Step 2: Handle the final GLB file (download or copy) ---
            if temp_file_path.startswith("http://") or temp_file_path.startswith(
                "https://"
            ):
                logger.info(f"TRELLIS returned URL, downloading GLB: {temp_file_path}")
                try:
                    with httpx.Client(timeout=120.0) as http_client:
                        response = http_client.get(temp_file_path)
                        response.raise_for_status()

                        glb_path.parent.mkdir(parents=True, exist_ok=True)

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
                if not Path(temp_file_path).exists():
                    raise RuntimeError(
                        f"Generated GLB file not found: {temp_file_path}. "
                    )

                glb_path.parent.mkdir(parents=True, exist_ok=True)

                shutil.copy(temp_file_path, glb_path)
                logger.info(
                    f"✓ TRELLIS GLB generated: {glb_path} ({os.path.getsize(glb_path)} bytes)"
                )

            return str(glb_path)

        except gradio_exceptions.AppError as app_error:
            logger.error(f"TRELLIS AppError: {app_error}")
            raise RuntimeError(
                f"TRELLIS Space returned an error during generation: {app_error}."
            ) from app_error
        except Exception as e:
            logger.error(f"TRELLIS image-to-3D generation failed: {e}")
            raise RuntimeError(f"3D model generation failed: {e}")
