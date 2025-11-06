"""Hugging Face Service for 3D model generation using TRELLIS."""

from __future__ import annotations

import logging
import os
import shutil
import uuid
from pathlib import Path
from gradio_client import Client

from config import (
    HF_TOKEN,
    MODEL_STORAGE_PATH,
)

logger = logging.getLogger(__name__)


class HuggingFaceService:
    """Handles 3D model generation using TRELLIS via Hugging Face Spaces.

    TRELLIS generates textured GLB files directly from text prompts.
    Space: dkatz2391/TRELLIS_TextTo3D_Try2
    """

    def __init__(self):
        """Initializes the TRELLIS Gradio Client."""
        if not HF_TOKEN:
            raise RuntimeError("HF_TOKEN not configured.")

        self.trellis_client: Client | None = None

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
            # TRELLIS: Single call to generate and extract GLB with textures
            # The /generate_and_extract_glb endpoint does everything in one step
            logger.info("Generating 3D model with TRELLIS...")

            from gradio_client import exceptions as gradio_exceptions

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
                    api_name="/generate_and_extract_glb",
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
                import httpx

                try:
                    with httpx.Client(timeout=60.0) as client:
                        response = client.get(glb_file_path)
                        response.raise_for_status()

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

                # Copy the generated GLB to our storage
                shutil.copy(glb_file_path, glb_path)
                logger.info(
                    f"✓ TRELLIS GLB generated: {glb_path} ({os.path.getsize(glb_path)} bytes)"
                )

            # Verify GLB structure (textures, materials)
            has_textures = False
            structure_info = {}
            try:
                has_textures, structure_info = self._verify_glb_structure(glb_path)
                if has_textures:
                    logger.info("✓ TRELLIS GLB has textures and materials!")
                else:
                    logger.warning(
                        "⚠️ TRELLIS GLB missing textures/materials. "
                        "This is unexpected - TRELLIS should export textures."
                    )
            except Exception as verify_error:
                logger.warning(
                    f"GLB verification failed (non-critical): {verify_error}"
                )

            # If no textures/materials, try to add basic material as fallback
            if not has_textures and structure_info.get("meshes", 0) > 0:
                logger.warning(
                    "⚠️ TRELLIS model has no textures/materials. "
                    "Attempting to add basic PBR material as fallback..."
                )
                try:
                    self._add_basic_material(glb_path)
                    # Re-verify
                    has_textures, _ = self._verify_glb_structure(glb_path)
                    if has_textures:
                        logger.info("✓ Successfully added basic material to GLB")
                    else:
                        logger.warning("⚠️ Added material but verification still fails")
                except Exception as material_error:
                    logger.error(
                        f"Failed to add basic material: {material_error}. "
                        "Model may appear white in AR."
                    )

            return str(glb_path)

        except Exception as e:
            logger.error(f"TRELLIS text-to-3D generation failed: {e}")
            raise RuntimeError(f"3D model generation failed: {e}")

    def _verify_glb_structure(self, glb_path: Path) -> tuple[bool, dict]:
        """Verify GLB structure to check for textures and materials.

        This helps diagnose why models appear white in AR.

        Args:
            glb_path: Path to the GLB file to verify

        Returns:
            Tuple of (has_textures, structure_info_dict)
        """
        try:
            from pygltflib import GLTF2

            gltf = GLTF2.load(str(glb_path))

            images_count = len(gltf.images) if gltf.images else 0
            textures_count = len(gltf.textures) if gltf.textures else 0
            materials_count = len(gltf.materials) if gltf.materials else 0
            meshes_count = len(gltf.meshes) if gltf.meshes else 0
            accessors_count = len(gltf.accessors) if gltf.accessors else 0

            # Check for vertex colors
            has_vertex_colors = False
            if gltf.meshes and gltf.accessors:
                for mesh in gltf.meshes:
                    if mesh.primitives:
                        for primitive in mesh.primitives:
                            if (
                                hasattr(primitive, "attributes")
                                and primitive.attributes
                            ):
                                attrs = primitive.attributes
                                if isinstance(attrs, dict):
                                    if attrs.get("COLOR_0") is not None:
                                        has_vertex_colors = True
                                        break
                            if has_vertex_colors:
                                break
                    if has_vertex_colors:
                        break

            # Check if materials have textures
            materials_with_textures = 0
            if gltf.materials:
                for material in gltf.materials:
                    pbr = getattr(material, "pbrMetallicRoughness", None)
                    if (
                        pbr
                        and hasattr(pbr, "baseColorTexture")
                        and pbr.baseColorTexture is not None
                    ):
                        materials_with_textures += 1

            structure_info = {
                "images": images_count,
                "textures": textures_count,
                "materials": materials_count,
                "meshes": meshes_count,
                "accessors": accessors_count,
                "materials_with_textures": materials_with_textures,
                "has_vertex_colors": has_vertex_colors,
            }

            logger.info(
                f"GLB Structure Verification: "
                f"Images: {images_count}, "
                f"Textures: {textures_count}, "
                f"Materials: {materials_count}, "
                f"Meshes: {meshes_count}, "
                f"Accessors: {accessors_count}, "
                f"Materials with textures: {materials_with_textures}, "
                f"Has vertex colors: {has_vertex_colors}"
            )

            has_textures = textures_count > 0 and materials_with_textures > 0

            if has_vertex_colors and textures_count == 0:
                logger.warning(
                    "⚠️ GLB uses vertex colors but has NO textures! "
                    "AR plugins don't support vertex colors - model will appear white."
                )
            elif textures_count > 0 and materials_with_textures == 0:
                logger.warning(
                    "⚠️ GLB has textures but materials don't reference them! "
                    "Textures exist but aren't linked to materials."
                )
            elif textures_count == 0 and materials_count == 0:
                logger.error(
                    "⚠️ GLB has NO textures and NO materials! "
                    "Model will definitely appear white in AR."
                )
            elif has_textures:
                logger.info(
                    "✓ GLB has textures and materials are properly linked. "
                    "Model should display correctly in AR."
                )

            return has_textures, structure_info

        except ImportError:
            logger.debug("pygltflib not available - skipping GLB verification")
            return False, {}
        except Exception as e:
            logger.warning(f"GLB verification error: {e}")
            import traceback

            logger.debug(f"GLB verification traceback: {traceback.format_exc()}")
            return False, {}

    def _add_basic_material(self, glb_path: Path) -> None:
        """Add a basic PBR material to a GLB file that has no materials.

        This is a fallback when Hunyuan3D-2 doesn't export materials/textures.
        Creates a simple gray material so the model isn't completely white.

        Args:
            glb_path: Path to the GLB file to modify
        """
        try:
            from pygltflib import GLTF2, Material, PbrMetallicRoughness

            logger.info(f"Loading GLB to add basic material: {glb_path}")
            gltf = GLTF2.load(str(glb_path))

            # Create a basic PBR material with gray color
            # This will at least make the model visible (not pure white)
            basic_material = Material(
                name="default_material",
                pbrMetallicRoughness=PbrMetallicRoughness(
                    baseColorFactor=[0.7, 0.7, 0.7, 1.0],  # Light gray
                    metallicFactor=0.0,
                    roughnessFactor=0.5,
                ),
                doubleSided=True,
            )

            # Add material to GLTF
            if gltf.materials is None:
                gltf.materials = []
            gltf.materials.append(basic_material)
            material_index = len(gltf.materials) - 1

            # Assign material to all meshes
            if gltf.meshes:
                for mesh in gltf.meshes:
                    if mesh.primitives:
                        for primitive in mesh.primitives:
                            primitive.material = material_index

            # Save the modified GLB
            gltf.save(str(glb_path))
            logger.info(f"✓ Added basic material to GLB: {glb_path}")

        except ImportError:
            logger.error("pygltflib not available - cannot add basic material")
            raise RuntimeError("pygltflib required for material injection")
        except Exception as e:
            logger.error(f"Failed to add basic material: {e}")
            import traceback

            logger.error(f"Material injection traceback: {traceback.format_exc()}")
            raise RuntimeError(f"Failed to add basic material: {e}") from e
