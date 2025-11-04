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
    HF_SDXL_MODEL,
    HF_TRIPOSR_MODEL,
)

# Configure logging
logging.basicConfig(
    level=logging.INFO, format="%(asctime)s - %(name)s - %(levelname)s - %(message)s"
)
logger = logging.getLogger(__name__)

# Initialize FastAPI application
app = FastAPI(title=API_TITLE, description=API_DESCRIPTION, version=API_VERSION)

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
    if HF_TOKEN:
        logger.info("✓ Hugging Face token configured - Model generation enabled")
        logger.info(f"  SDXL Model: {HF_SDXL_MODEL}")
        logger.info(f"  TripoSR Model: {HF_TRIPOSR_MODEL}")
    else:
        logger.error("✗ HF_TOKEN not configured - Model generation will fail!")
        logger.error("  Set HF_TOKEN environment variable to enable generation")
        logger.error("  Get your token from: https://huggingface.co/settings/tokens")
    logger.info(
        f"API server started. Visit http://localhost:8000/docs for API documentation"
    )


if __name__ == "__main__":
    import uvicorn
    from config import HOST, PORT

    uvicorn.run(app, host=HOST, port=PORT)
