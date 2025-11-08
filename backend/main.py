"""Main application entry point for PromptAR Backend API."""

import logging
import sys
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


class ColoredFormatter(logging.Formatter):
    """Custom formatter with colored output for different log levels."""

    # ANSI color codes
    COLORS = {
        "DEBUG": "\033[36m",  # Cyan
        "INFO": "\033[0m",  # White/Reset
        "WARNING": "\033[33m",  # Yellow
        "ERROR": "\033[31m",  # Red
        "CRITICAL": "\033[35m",  # Magenta
    }
    RESET = "\033[0m"
    BOLD = "\033[1m"

    def format(self, record):
        # Get the color for this log level
        color = self.COLORS.get(record.levelname, self.RESET)
        
        # Format the base message
        log_message = super().format(record)
        
        # For ERROR and CRITICAL, color the entire message
        if record.levelname in ["ERROR", "CRITICAL"]:
            # Color the whole message, with bold levelname
            levelname_colored = f"{self.BOLD}{color}{record.levelname}{self.RESET}{color}"
            log_message = log_message.replace(record.levelname, levelname_colored)
            log_message = f"{color}{log_message}{self.RESET}"
        else:
            # For other levels, just color the levelname (bold)
            levelname_colored = f"{self.BOLD}{color}{record.levelname}{self.RESET}"
            log_message = log_message.replace(record.levelname, levelname_colored)
        
        return log_message


# Configure colored logging
def setup_colored_logging():
    """Set up colored logging configuration."""
    # Create console handler
    console_handler = logging.StreamHandler(sys.stdout)
    console_handler.setLevel(logging.INFO)
    
    # Create formatter with colors
    formatter = ColoredFormatter(
        "%(asctime)s - %(name)s - %(levelname)s - %(message)s",
        datefmt="%Y-%m-%d %H:%M:%S"
    )
    console_handler.setFormatter(formatter)
    
    # Configure root logger
    root_logger = logging.getLogger()
    root_logger.setLevel(logging.INFO)
    root_logger.handlers = []  # Clear existing handlers
    root_logger.addHandler(console_handler)
    
    # Suppress noisy loggers
    logging.getLogger("uvicorn.access").setLevel(logging.WARNING)
    logging.getLogger("uvicorn").setLevel(logging.INFO)


# Setup colored logging
setup_colored_logging()
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
        logger.warning("⚠️  HF_TOKEN not configured - Some Spaces may require authentication")

    logger.info(
        f"API server started. Visit http://localhost:8000/docs for API documentation"
    )


if __name__ == "__main__":
    import uvicorn
    from config import HOST, PORT

    uvicorn.run(app, host=HOST, port=PORT)
