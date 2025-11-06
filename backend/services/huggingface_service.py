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

            # Note: Brightness normalization is now applied on download, not during generation
            # This allows flexibility to adjust normalization settings without regenerating models

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

    def _normalize_materials_for_ar(self, glb_path: Path) -> None:
        """Normalize materials in GLB/GLTF file for AR visibility.

        This method can be applied to both GLB and GLTF files directly.
        It adjusts material properties to ensure models appear bright in AR.

        Args:
            glb_path: Path to the GLB or GLTF file to modify
        """
        try:
            from pygltflib import GLTF2

            # Material brightness configuration for AR visibility
            # Adjust these values to control model brightness:
            # - Higher emissive = brighter glow (0.0-1.0, typical: 0.2-0.5)
            # - Higher baseColor boost = brighter colors (1.0 = no change, 1.5 = 50% brighter)
            # - Lower metallic threshold = more materials become non-metallic (0.0-1.0)
            # - Higher roughness min = more matte surface (0.0-1.0, typical: 0.7-1.0)
            BRIGHTNESS_CONFIG = {
                "metallic_threshold": 0.1,  # Any metallicFactor > this becomes 0.0
                "metallic_target": 0.0,  # Target metallicFactor for bright materials
                "roughness_min": 0.9,  # Minimum roughnessFactor (higher = more matte)
                "base_color_boost": 1.5,  # Multiplier for baseColorFactor (1.5 = 50% brighter)
                "emissive_base": 0.3,  # Base emissive glow (0.0-1.0)
                "emissive_max": 0.5,  # Maximum emissive glow (0.0-1.0)
            }

            logger.info(f"Loading GLB/GLTF for brightness normalization: {glb_path}")
            gltf = GLTF2.load(str(glb_path))

            # Normalize materials to ensure they render correctly in AR
            # High metallicFactor can cause models to appear dark/black
            # BoxTextured works because it has metallicFactor=0.0 (non-metallic)
            if gltf.materials:
                for i, material in enumerate(gltf.materials):
                    if (
                        hasattr(material, "pbrMetallicRoughness")
                        and material.pbrMetallicRoughness
                    ):
                        pbr = material.pbrMetallicRoughness

                        # If metallicFactor is too high, reduce it to target value
                        # High metallic = mirrors environment, needs strong lighting
                        # Non-metallic (0.0) = uses base color/texture, works better in AR
                        if (
                            hasattr(pbr, "metallicFactor")
                            and pbr.metallicFactor is not None
                        ):
                            original_metallic = pbr.metallicFactor
                            if (
                                original_metallic
                                > BRIGHTNESS_CONFIG["metallic_threshold"]
                            ):
                                pbr.metallicFactor = BRIGHTNESS_CONFIG[
                                    "metallic_target"
                                ]
                                logger.info(
                                    f"Normalized material {i}: metallicFactor {original_metallic} -> {pbr.metallicFactor} "
                                    f"(threshold: {BRIGHTNESS_CONFIG['metallic_threshold']}, target: {BRIGHTNESS_CONFIG['metallic_target']})"
                                )

                        # Ensure roughnessFactor is reasonable (0.0-1.0)
                        # Lower roughness = more shiny, but can also appear darker
                        # Higher roughness = more matte, better visibility
                        if (
                            hasattr(pbr, "roughnessFactor")
                            and pbr.roughnessFactor is not None
                        ):
                            if pbr.roughnessFactor < BRIGHTNESS_CONFIG["roughness_min"]:
                                # Increase roughness to minimum for maximum visibility
                                pbr.roughnessFactor = max(
                                    pbr.roughnessFactor,
                                    BRIGHTNESS_CONFIG["roughness_min"],
                                )
                                logger.info(
                                    f"Normalized material {i}: roughnessFactor -> {pbr.roughnessFactor} "
                                    f"(min: {BRIGHTNESS_CONFIG['roughness_min']})"
                                )

                        # Ensure baseColorFactor is set (white if missing)
                        if (
                            not hasattr(pbr, "baseColorFactor")
                            or pbr.baseColorFactor is None
                        ):
                            pbr.baseColorFactor = [1.0, 1.0, 1.0, 1.0]
                            logger.info(
                                f"Added baseColorFactor to material {i} (white)"
                            )
                        else:
                            # Boost baseColorFactor to increase brightness
                            base_color = pbr.baseColorFactor
                            if isinstance(base_color, list) and len(base_color) >= 3:
                                # Apply brightness boost multiplier
                                boost = BRIGHTNESS_CONFIG["base_color_boost"]
                                boosted_color = [
                                    min(1.0, base_color[0] * boost),
                                    min(1.0, base_color[1] * boost),
                                    min(1.0, base_color[2] * boost),
                                    base_color[3] if len(base_color) > 3 else 1.0,
                                ]
                                if boosted_color != base_color:
                                    pbr.baseColorFactor = boosted_color
                                    boost_percent = int((boost - 1.0) * 100)
                                    logger.info(
                                        f"Boosted baseColorFactor for material {i} "
                                        f"({boost_percent}% brightness increase, multiplier: {boost})"
                                    )

                    # Add emissive factor to make models super bright and visible
                    if (
                        not hasattr(material, "emissiveFactor")
                        or material.emissiveFactor is None
                    ):
                        emissive_value = BRIGHTNESS_CONFIG["emissive_base"]
                        material.emissiveFactor = [
                            emissive_value,
                            emissive_value,
                            emissive_value,
                        ]
                        logger.info(
                            f"Added emissiveFactor to material {i} "
                            f"(glow: {emissive_value}, config: {BRIGHTNESS_CONFIG['emissive_base']})"
                        )
                    else:
                        # Boost existing emissive
                        emissive = material.emissiveFactor
                        if isinstance(emissive, list) and len(emissive) >= 3:
                            emissive_max = BRIGHTNESS_CONFIG["emissive_max"]
                            emissive_base = BRIGHTNESS_CONFIG["emissive_base"]
                            boosted_emissive = [
                                min(emissive_max, emissive[0] + emissive_base),
                                min(emissive_max, emissive[1] + emissive_base),
                                min(emissive_max, emissive[2] + emissive_base),
                            ]
                            material.emissiveFactor = boosted_emissive
                            logger.info(
                                f"Boosted emissiveFactor for material {i} "
                                f"(glow: {boosted_emissive}, max: {emissive_max})"
                            )

            # Save the modified GLB/GLTF file
            gltf.save(str(glb_path))
            logger.info(f"✓ Brightness normalization saved to: {glb_path}")

        except ImportError:
            logger.error("pygltflib not available - cannot normalize materials")
            raise RuntimeError("pygltflib required for material normalization")
        except Exception as e:
            logger.error(f"Failed to normalize materials: {e}")
            import traceback

            logger.error(f"Material normalization traceback: {traceback.format_exc()}")
            raise RuntimeError(f"Failed to normalize materials: {e}") from e

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

    def convert_glb_to_gltf(self, glb_path: Path, model_id: str | None = None) -> str:
        """Convert GLB file to GLTF format (extracts textures and bin files).

        This is useful when GLB files don't render correctly in AR plugins.
        GLTF format with separate files often works better for AR rendering.

        Args:
            glb_path: Path to the GLB file to convert
            model_id: Optional model ID for the output folder name

        Returns:
            Path to the generated GLTF file
        """
        try:
            from pygltflib import GLTF2
            import base64
            import json as json_module

            if not glb_path.exists():
                raise RuntimeError(f"GLB file not found: {glb_path}")

            logger.info(f"Converting GLB to GLTF: {glb_path}")

            # Load GLB file
            gltf = GLTF2.load(str(glb_path))

            # Create output directory for GLTF files
            model_id = model_id or glb_path.stem
            output_dir = self.storage_path / model_id
            output_dir.mkdir(parents=True, exist_ok=True)

            gltf_path = output_dir / f"{model_id}.gltf"

            # Extract buffers (bin files) and images (textures) from GLB
            # Convert embedded buffers to external files
            # For GLB files, we need to read the binary chunk manually
            # Store buffer data for texture embedding later
            buffer_data_dict = {}

            if gltf.buffers:
                # Read the GLB file to extract binary chunks
                with open(glb_path, "rb") as f:
                    glb_data = f.read()

                # GLB format: 12-byte header + JSON chunk + Binary chunk(s)
                # Parse GLB structure to extract binary data
                import struct

                # Read GLB header (12 bytes)
                magic = struct.unpack("<I", glb_data[0:4])[0]
                version = struct.unpack("<I", glb_data[4:8])[0]
                length = struct.unpack("<I", glb_data[8:12])[0]

                if magic != 0x46546C67:  # "glTF" in ASCII
                    raise RuntimeError("Invalid GLB file format")

                offset = 12
                json_chunk_length = struct.unpack("<I", glb_data[offset : offset + 4])[
                    0
                ]
                offset += 4
                json_chunk_type = struct.unpack("<I", glb_data[offset : offset + 4])[0]
                offset += 4

                # Skip JSON chunk (we already have it loaded)
                offset += json_chunk_length
                # Align to 4-byte boundary
                offset = (offset + 3) & ~3

                # Extract binary chunks
                for i, buffer in enumerate(gltf.buffers):
                    if buffer.uri is None:  # Embedded buffer
                        # Read binary chunk header
                        if offset >= len(glb_data):
                            logger.warning(f"Buffer {i} offset beyond file size")
                            break

                        bin_chunk_length = struct.unpack(
                            "<I", glb_data[offset : offset + 4]
                        )[0]
                        offset += 4
                        bin_chunk_type = struct.unpack(
                            "<I", glb_data[offset : offset + 4]
                        )[0]
                        offset += 4

                        if bin_chunk_type != 0x004E4942:  # "BIN\0" in ASCII
                            logger.warning(f"Buffer {i} is not binary chunk type")
                            continue

                        # Extract binary data
                        buffer_data = glb_data[offset : offset + bin_chunk_length]
                        offset += bin_chunk_length
                        # Align to 4-byte boundary
                        offset = (offset + 3) & ~3

                        # Store buffer data for later use (texture embedding)
                        buffer_data_dict[i] = buffer_data

                        if buffer_data:
                            bin_filename = f"{model_id}_{i}.bin"
                            bin_path = output_dir / bin_filename

                            with open(bin_path, "wb") as f:
                                f.write(buffer_data)

                            # Update buffer to reference external file
                            buffer.uri = bin_filename
                            logger.info(
                                f"Extracted buffer {i} to {bin_filename} (size: {len(buffer_data)} bytes)"
                            )

            # Extract images (textures) from GLB
            if gltf.images:
                for i, image in enumerate(gltf.images):
                    image_data = None
                    needs_extraction = False

                    # Check if image has bufferView (embedded or conflict with uri)
                    if hasattr(image, "bufferView") and image.bufferView is not None:
                        needs_extraction = True

                        # Get buffer view data
                        buffer_view = gltf.bufferViews[image.bufferView]
                        buffer = gltf.buffers[buffer_view.buffer]

                        # Read the buffer data (we already extracted it above)
                        bin_filename = f"{model_id}_{buffer_view.buffer}.bin"
                        bin_path = output_dir / bin_filename

                        if bin_path.exists():
                            with open(bin_path, "rb") as f:
                                buffer_data = f.read()

                            # Extract image data from buffer view
                            start = buffer_view.byteOffset or 0
                            end = start + (buffer_view.byteLength or 0)
                            image_data = buffer_data[start:end]
                        else:
                            logger.warning(
                                f"Buffer file not found for image {i}: {bin_filename}"
                            )
                            continue

                    # Handle data URI images
                    elif image.uri and image.uri.startswith("data:"):
                        needs_extraction = True
                        # Extract from data URI
                        header, data = image.uri.split(",", 1)
                        image_data = base64.b64decode(data)

                    # Extract image to file if needed
                    if needs_extraction and image_data:
                        # Determine file extension from MIME type or data
                        if hasattr(image, "mimeType") and image.mimeType:
                            mime_type = image.mimeType
                        elif image.uri and image.uri.startswith("data:"):
                            mime_type = image.uri.split(";")[0].split(":")[1]
                        else:
                            mime_type = "image/png"  # Default

                        ext = ".png" if "png" in mime_type.lower() else ".jpg"
                        image_filename = f"{model_id}_texture_{i}{ext}"
                        image_path = output_dir / image_filename

                        with open(image_path, "wb") as f:
                            f.write(image_data)

                        # IMPORTANT: Keep bufferView reference even after extraction
                        # Some AR plugins (like ar_flutter_plugin_2) prefer bufferView when both exist
                        # BoxTextured works because it has both uri and bufferView
                        # The bufferView points to embedded texture in the .bin file
                        # The URI points to the extracted .png file
                        # Both are valid - plugin can use either
                        original_buffer_view = getattr(image, "bufferView", None)

                        # Set URI to point to extracted file (for fallback)
                        image.uri = image_filename

                        # CRITICAL: Keep bufferView if it existed (don't remove it)
                        # BoxTextured works with both uri and bufferView - match that behavior
                        # The texture is extracted to file (via URI) but also remains in .bin (via bufferView)
                        if original_buffer_view is not None:
                            # Keep bufferView - plugin can use embedded data from .bin
                            # This matches BoxTextured which works correctly
                            logger.info(
                                f"Keeping bufferView {original_buffer_view} for texture {i} (file: {image_filename})"
                            )
                            logger.info(
                                f"  Plugin can use bufferView (embedded) or URI (file) - both work"
                            )
                        else:
                            # No bufferView existed - this is the case for tiger
                            # We need to ensure URI is correct since it's the only reference
                            logger.warning(
                                f"Texture {i} has no bufferView - using URI only: {image_filename}"
                            )
                            logger.warning(
                                f"  This may cause issues if plugin prefers bufferView"
                            )

                        if hasattr(image, "mimeType"):
                            image.mimeType = (
                                None  # Remove MIME type since we're using external file
                            )
                        logger.info(
                            f"Extracted texture {i} to {image_filename} (size: {len(image_data)} bytes)"
                        )

                        # CRITICAL: Ensure URI is a simple filename (relative to GLTF directory)
                        # Some AR plugins require relative paths to be just the filename
                        if "/" in image_filename or "\\" in image_filename:
                            # Extract just the filename
                            simple_filename = image_filename.split("/")[-1].split("\\")[
                                -1
                            ]
                            if simple_filename != image_filename:
                                logger.info(
                                    f"Normalizing texture URI from '{image_filename}' to '{simple_filename}'"
                                )
                                image.uri = simple_filename
                    elif image.uri and not image.uri.startswith("data:"):
                        # Image already has a URI (external file) but no bufferView
                        # CRITICAL: For models that only have URI (like tiger), the plugin may not load textures
                        # Solution: Embed the texture into the buffer so we can create a bufferView
                        # This matches BoxTextured behavior which works correctly

                        # Check if texture file exists in the output directory
                        texture_uri = image.uri
                        # Normalize path (remove any subdirectories)
                        if "/" in texture_uri or "\\" in texture_uri:
                            texture_filename = texture_uri.split("/")[-1].split("\\")[
                                -1
                            ]
                        else:
                            texture_filename = texture_uri

                        texture_path = output_dir / texture_filename

                        # If texture file exists, embed it into buffer
                        if texture_path.exists():
                            logger.info(
                                f"Embedding texture {i} into buffer (file: {texture_filename})"
                            )

                            # Read texture file
                            with open(texture_path, "rb") as f:
                                texture_data = f.read()

                            # Find the main buffer (usually buffer 0)
                            main_buffer_idx = 0
                            if gltf.buffers:
                                # Use the first buffer
                                main_buffer = gltf.buffers[main_buffer_idx]

                                # Read current buffer data
                                if main_buffer_idx in buffer_data_dict:
                                    current_buffer_data = buffer_data_dict[
                                        main_buffer_idx
                                    ]
                                else:
                                    # Read from file if it exists
                                    bin_filename = f"{model_id}_{main_buffer_idx}.bin"
                                    bin_path = output_dir / bin_filename
                                    if bin_path.exists():
                                        with open(bin_path, "rb") as f:
                                            current_buffer_data = f.read()
                                    else:
                                        current_buffer_data = b""

                                # Append texture data to buffer
                                texture_offset = len(current_buffer_data)
                                # Align to 4-byte boundary
                                if texture_offset % 4 != 0:
                                    padding = 4 - (texture_offset % 4)
                                    current_buffer_data += b"\x00" * padding
                                    texture_offset = len(current_buffer_data)

                                new_buffer_data = current_buffer_data + texture_data

                                # Update buffer file
                                bin_filename = f"{model_id}_{main_buffer_idx}.bin"
                                bin_path = output_dir / bin_filename
                                with open(bin_path, "wb") as f:
                                    f.write(new_buffer_data)

                                # Update buffer length
                                main_buffer.byteLength = len(new_buffer_data)
                                buffer_data_dict[main_buffer_idx] = new_buffer_data

                                # Create a new bufferView for the texture
                                new_buffer_view = {
                                    "buffer": main_buffer_idx,
                                    "byteOffset": texture_offset,
                                    "byteLength": len(texture_data),
                                }

                                # Add bufferView to GLTF
                                if (
                                    not hasattr(gltf, "bufferViews")
                                    or gltf.bufferViews is None
                                ):
                                    gltf.bufferViews = []

                                new_buffer_view_idx = len(gltf.bufferViews)
                                gltf.bufferViews.append(new_buffer_view)

                                # Set image to use bufferView (keep URI as fallback)
                                image.bufferView = new_buffer_view_idx
                                image.uri = texture_filename  # Keep URI as fallback

                                logger.info(
                                    f"  Created bufferView {new_buffer_view_idx} for texture {i}"
                                )
                                logger.info(
                                    f"  Texture embedded at offset {texture_offset} in buffer {main_buffer_idx}"
                                )
                                logger.info(
                                    f"  Now has both bufferView and URI (like BoxTextured)"
                                )
                            else:
                                logger.warning(
                                    f"  No buffers available to embed texture"
                                )
                                # Just normalize URI
                                image.uri = texture_filename
                        else:
                            logger.warning(f"Texture file not found: {texture_path}")
                            # Just normalize URI
                            image.uri = texture_filename

                        # Ensure URI is relative (not absolute path)
                        if not image.uri.startswith("http") and "/" in image.uri:
                            # Keep only the filename for relative paths
                            filename = image.uri.split("/")[-1]
                            if filename != image.uri:
                                logger.info(
                                    f"Normalizing image URI from '{image.uri}' to '{filename}'"
                                )
                                image.uri = filename

            # Normalize materials for AR brightness (apply to GLTF object in memory)
            # Since we're converting GLB to GLTF, we normalize the GLTF object before saving
            # This ensures brightness is normalized even if GLB wasn't normalized
            # Material brightness configuration for AR visibility
            # Adjust these values to control model brightness:
            # - Higher emissive = brighter glow (0.0-1.0, typical: 0.2-0.5)
            # - Higher baseColor boost = brighter colors (1.0 = no change, 1.5 = 50% brighter)
            # - Lower metallic threshold = more materials become non-metallic (0.0-1.0)
            # - Higher roughness min = more matte surface (0.0-1.0, typical: 0.7-1.0)
            BRIGHTNESS_CONFIG = {
                "metallic_threshold": 0.1,  # Any metallicFactor > this becomes 0.0
                "metallic_target": 0.0,  # Target metallicFactor for bright materials
                "roughness_min": 0.9,  # Minimum roughnessFactor (higher = more matte)
                "base_color_boost": 1.5,  # Multiplier for baseColorFactor (1.5 = 50% brighter)
                "emissive_base": 0.3,  # Base emissive glow (0.0-1.0)
                "emissive_max": 0.5,  # Maximum emissive glow (0.0-1.0)
            }

            # Normalize materials to ensure they render correctly in AR
            # High metallicFactor can cause models to appear dark/black
            # BoxTextured works because it has metallicFactor=0.0 (non-metallic)
            if gltf.materials:
                for i, material in enumerate(gltf.materials):
                    if (
                        hasattr(material, "pbrMetallicRoughness")
                        and material.pbrMetallicRoughness
                    ):
                        pbr = material.pbrMetallicRoughness

                        # If metallicFactor is too high, reduce it to target value
                        # High metallic = mirrors environment, needs strong lighting
                        # Non-metallic (0.0) = uses base color/texture, works better in AR
                        if (
                            hasattr(pbr, "metallicFactor")
                            and pbr.metallicFactor is not None
                        ):
                            original_metallic = pbr.metallicFactor
                            if (
                                original_metallic
                                > BRIGHTNESS_CONFIG["metallic_threshold"]
                            ):
                                pbr.metallicFactor = BRIGHTNESS_CONFIG[
                                    "metallic_target"
                                ]
                                logger.info(
                                    f"Normalized material {i}: metallicFactor {original_metallic} -> {pbr.metallicFactor} "
                                    f"(threshold: {BRIGHTNESS_CONFIG['metallic_threshold']}, target: {BRIGHTNESS_CONFIG['metallic_target']})"
                                )

                        # Ensure roughnessFactor is reasonable (0.0-1.0)
                        # Lower roughness = more shiny, but can also appear darker
                        # Higher roughness = more matte, better visibility
                        if (
                            hasattr(pbr, "roughnessFactor")
                            and pbr.roughnessFactor is not None
                        ):
                            if pbr.roughnessFactor < BRIGHTNESS_CONFIG["roughness_min"]:
                                # Increase roughness to minimum for maximum visibility
                                pbr.roughnessFactor = max(
                                    pbr.roughnessFactor,
                                    BRIGHTNESS_CONFIG["roughness_min"],
                                )
                                logger.info(
                                    f"Normalized material {i}: roughnessFactor -> {pbr.roughnessFactor} "
                                    f"(min: {BRIGHTNESS_CONFIG['roughness_min']})"
                                )

                        # Ensure baseColorFactor is set (white if missing)
                        if (
                            not hasattr(pbr, "baseColorFactor")
                            or pbr.baseColorFactor is None
                        ):
                            pbr.baseColorFactor = [1.0, 1.0, 1.0, 1.0]
                            logger.info(
                                f"Added baseColorFactor to material {i} (white)"
                            )
                        else:
                            # Boost baseColorFactor to increase brightness
                            base_color = pbr.baseColorFactor
                            if isinstance(base_color, list) and len(base_color) >= 3:
                                # Apply brightness boost multiplier
                                boost = BRIGHTNESS_CONFIG["base_color_boost"]
                                boosted_color = [
                                    min(1.0, base_color[0] * boost),
                                    min(1.0, base_color[1] * boost),
                                    min(1.0, base_color[2] * boost),
                                    base_color[3] if len(base_color) > 3 else 1.0,
                                ]
                                if boosted_color != base_color:
                                    pbr.baseColorFactor = boosted_color
                                    boost_percent = int((boost - 1.0) * 100)
                                    logger.info(
                                        f"Boosted baseColorFactor for material {i} "
                                        f"({boost_percent}% brightness increase, multiplier: {boost})"
                                    )

                    # Add emissive factor to make models super bright and visible
                    if (
                        not hasattr(material, "emissiveFactor")
                        or material.emissiveFactor is None
                    ):
                        emissive_value = BRIGHTNESS_CONFIG["emissive_base"]
                        material.emissiveFactor = [
                            emissive_value,
                            emissive_value,
                            emissive_value,
                        ]
                        logger.info(
                            f"Added emissiveFactor to material {i} "
                            f"(glow: {emissive_value}, config: {BRIGHTNESS_CONFIG['emissive_base']})"
                        )
                    else:
                        # Boost existing emissive
                        emissive = material.emissiveFactor
                        if isinstance(emissive, list) and len(emissive) >= 3:
                            emissive_max = BRIGHTNESS_CONFIG["emissive_max"]
                            emissive_base = BRIGHTNESS_CONFIG["emissive_base"]
                            boosted_emissive = [
                                min(emissive_max, emissive[0] + emissive_base),
                                min(emissive_max, emissive[1] + emissive_base),
                                min(emissive_max, emissive[2] + emissive_base),
                            ]
                            material.emissiveFactor = boosted_emissive
                            logger.info(
                                f"Boosted emissiveFactor for material {i} "
                                f"(glow: {boosted_emissive}, max: {emissive_max})"
                            )

            # Save GLTF file (JSON format)
            # Note: We've already extracted buffers and set URIs, so we just save the JSON
            # The save() method doesn't have embed_buffer parameter - buffers are already external
            gltf.save(str(gltf_path))
            logger.info(f"✓ GLTF saved: {gltf_path}")

            # Verify output files
            if not gltf_path.exists():
                raise RuntimeError(f"GLTF file was not created: {gltf_path}")

            logger.info(f"✓ GLB to GLTF conversion completed: {gltf_path}")
            return str(gltf_path)

        except ImportError:
            logger.error("pygltflib not available - cannot convert GLB to GLTF")
            raise RuntimeError("pygltflib required for GLB to GLTF conversion")
        except Exception as e:
            logger.error(f"Failed to convert GLB to GLTF: {e}")
            import traceback

            logger.error(f"Conversion traceback: {traceback.format_exc()}")
            raise RuntimeError(f"Failed to convert GLB to GLTF: {e}") from e

    def create_gltf_zip(self, glb_path: Path, model_id: str | None = None) -> str:
        """Convert GLB to GLTF and create a zip archive containing all files.

        This is the recommended approach for GLTF distribution:
        - Single file download (faster, atomic)
        - Smaller size due to compression
        - Easier to cache and manage
        - Common practice in 3D model distribution

        Args:
            glb_path: Path to the GLB file to convert
            model_id: Optional model ID for the output folder/zip name

        Returns:
            Path to the created zip file
        """
        import zipfile
        import shutil

        try:
            # First convert GLB to GLTF (extracts textures and bin files)
            gltf_path = Path(self.convert_glb_to_gltf(glb_path, model_id))
            model_id = model_id or glb_path.stem

            # Output directory where GLTF files are stored
            output_dir = self.storage_path / model_id

            # Create zip file
            zip_path = self.storage_path / f"{model_id}.zip"

            logger.info(f"Creating GLTF zip archive: {zip_path}")

            # Create zip with all GLTF files
            with zipfile.ZipFile(zip_path, "w", zipfile.ZIP_DEFLATED) as zipf:
                # Add all files in the GLTF directory
                for file_path in output_dir.rglob("*"):
                    if file_path.is_file():
                        # Add file to zip with relative path from output_dir
                        arcname = file_path.relative_to(output_dir)
                        zipf.write(file_path, arcname)
                        logger.debug(f"Added to zip: {arcname}")

            zip_size = zip_path.stat().st_size
            logger.info(f"✓ GLTF zip created: {zip_path} ({zip_size} bytes)")

            return str(zip_path)

        except Exception as e:
            logger.error(f"Failed to create GLTF zip: {e}")
            import traceback

            logger.error(f"Zip creation traceback: {traceback.format_exc()}")
            raise RuntimeError(f"Failed to create GLTF zip: {e}") from e
