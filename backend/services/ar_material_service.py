"""AR Material Processing Service for normalizing 3D model materials for AR visibility."""

import logging
from pathlib import Path
from typing import TYPE_CHECKING

if TYPE_CHECKING:
    from pygltflib import GLTF2

logger = logging.getLogger(__name__)

# ============================================================================
# Configuration
# ============================================================================

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

# ============================================================================
# Core Material Normalization Functions
# ============================================================================


def normalize_gltf_materials(gltf: "GLTF2") -> None:
    """Normalize materials in a GLTF object (in-memory) for AR visibility.

    This function works on a GLTF object that's already loaded in memory.
    It adjusts material properties to ensure models appear bright in AR.

    Args:
        gltf: GLTF2 object to normalize
    """
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
                if hasattr(pbr, "metallicFactor") and pbr.metallicFactor is not None:
                    original_metallic = pbr.metallicFactor
                    if original_metallic > BRIGHTNESS_CONFIG["metallic_threshold"]:
                        pbr.metallicFactor = BRIGHTNESS_CONFIG["metallic_target"]
                        logger.info(
                            f"Normalized material {i}: metallicFactor {original_metallic} -> {pbr.metallicFactor} "
                            f"(threshold: {BRIGHTNESS_CONFIG['metallic_threshold']}, target: {BRIGHTNESS_CONFIG['metallic_target']})"
                        )

                # Ensure roughnessFactor is reasonable (0.0-1.0)
                # Lower roughness = more shiny, but can also appear darker
                # Higher roughness = more matte, better visibility
                if hasattr(pbr, "roughnessFactor") and pbr.roughnessFactor is not None:
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
                if not hasattr(pbr, "baseColorFactor") or pbr.baseColorFactor is None:
                    pbr.baseColorFactor = [1.0, 1.0, 1.0, 1.0]
                    logger.info(f"Added baseColorFactor to material {i} (white)")
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


# ============================================================================
# File-based Material Normalization
# ============================================================================


def normalize_materials_for_ar(glb_path: Path) -> None:
    """Normalize materials in GLB/GLTF file for AR visibility.

    This function can be applied to both GLB and GLTF files directly.
    It adjusts material properties to ensure models appear bright in AR.

    Args:
        glb_path: Path to the GLB or GLTF file to modify
    """
    try:
        from pygltflib import GLTF2

        logger.info(f"Loading GLB/GLTF for brightness normalization: {glb_path}")
        gltf = GLTF2.load(str(glb_path))

        # Normalize materials using the shared function
        normalize_gltf_materials(gltf)

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
