"""Main application entry point for PromptAR Backend API."""

import logging

from utils.logging_config import setup_colored_logging
from app.app import create_app, set_hf_service
from config import HOST, PORT, HF_TOKEN

# Setup colored logging before creating app
setup_colored_logging()
logger = logging.getLogger(__name__)

# Create FastAPI application
app = create_app()


async def startup_event():
    """Handle application startup events."""
    # Initialize HuggingFaceService (works with or without HF_TOKEN)
    try:
        from services.huggingface_service import HuggingFaceService

        logger.info("Initializing HuggingFaceService")
        hf_service = HuggingFaceService()
        set_hf_service(hf_service)
        logger.info("✓ HuggingFaceService initialized successfully")
    except Exception as e:
        logger.error(f"❌ Failed to initialize HuggingFaceService: {e}")
        set_hf_service(None)

    if not HF_TOKEN:
        logger.warning(
            "⚠️  HF_TOKEN not configured - Some Spaces may require authentication"
        )

    logger.info(
        "API server started. Visit http://localhost:8000/docs for API documentation"
    )


# Register startup event
app.on_event("startup")(startup_event)


if __name__ == "__main__":
    import uvicorn

    uvicorn.run(app, host=HOST, port=PORT)
