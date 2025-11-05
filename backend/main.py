"""Main application entry point for PromptAR Backend API."""

import logging
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from routers import models_router, root_router
from config import (
    API_TITLE,
    API_DESCRIPTION,
    API_VERSION,
    ALLOWED_ORIGINS,
    HF_TOKEN,
)

# Configure logging
logging.basicConfig(
    level=logging.INFO, format="%(asctime)s - %(name)s - %(levelname)s - %(message)s"
)
logger = logging.getLogger(__name__)

# Initialize FastAPI application
app = FastAPI(title=API_TITLE, description=API_DESCRIPTION, version=API_VERSION)

# Initialize HuggingFaceService
hf_service = None

# Configure CORS (needed for Flutter web and mobile apps)
app.add_middleware(
    CORSMiddleware,
    allow_origins=ALLOWED_ORIGINS,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Include routers
app.include_router(root_router)
app.include_router(models_router)


# Log startup info
@app.on_event("startup")
async def startup_event():
    global hf_service

    if HF_TOKEN:

        # Initialize HuggingFaceService
        try:
            from services.huggingface_service import HuggingFaceService

            logger.info("Initializing HuggingFaceService")
            hf_service = HuggingFaceService()
            logger.info("✓ HuggingFaceService initialized successfully")
        except Exception as e:
            logger.error(f"❌ Failed to initialize HuggingFaceService: {e}")
            hf_service = None
    else:
        logger.error("❌ HF_TOKEN not configured - Model generation will fail!")

    logger.info(
        f"API server started. Visit http://localhost:8000/docs for API documentation"
    )


if __name__ == "__main__":
    import uvicorn
    from config import HOST, PORT

    uvicorn.run(app, host=HOST, port=PORT)
