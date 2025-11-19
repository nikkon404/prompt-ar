"""Application factory for creating and configuring the FastAPI application."""

import logging
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from config import (
    API_TITLE,
    API_DESCRIPTION,
    API_VERSION,
    ALLOWED_ORIGINS,
    DB_PATH,
)
from routers import models_router, root_router
from services.database_service import DatabaseService
from middleware.request_logging import RequestLoggingMiddleware
from middleware.global_rate_limit import GlobalRateLimitMiddleware

logger = logging.getLogger(__name__)

# Global service instances
hf_service = None
database_service = None


def create_app() -> FastAPI:
    """Create and configure the FastAPI application.

    Returns:
        Configured FastAPI application instance
    """
    # Create FastAPI app
    app = FastAPI(
        title=API_TITLE,
        description=API_DESCRIPTION,
        version=API_VERSION,
    )

    # Initialize database service
    _initialize_database_service()

    # Add middleware
    _setup_middleware(app)

    # Include routers
    _setup_routers(app)

    return app


def _initialize_database_service():
    """Initialize the database service for request logging."""
    global database_service

    try:
        logger.info(f"Initializing database service for request logging (path: {DB_PATH})")
        database_service = DatabaseService(db_path=DB_PATH)
        logger.info(f"✓ Database service initialized successfully at {DB_PATH}")
    except Exception as e:
        logger.error(f"❌ Failed to initialize database service: {e}")
        database_service = None


def _setup_middleware(app: FastAPI):
    """Configure middleware for the application.

    Args:
        app: FastAPI application instance
    """
    # Add global rate limiting middleware (5 requests/minute per IP)
    app.add_middleware(GlobalRateLimitMiddleware)
    logger.info("✓ Global rate limiting middleware added")
    
    # Add request logging middleware (must be before CORS middleware to capture all requests)
    if database_service:
        app.add_middleware(RequestLoggingMiddleware, database_service=database_service)
        logger.info("✓ Request logging middleware added")
    else:
        logger.warning(
            "⚠️  Request logging middleware not added - database service not initialized"
        )

    # Configure CORS (needed for Flutter web and mobile apps)
    app.add_middleware(
        CORSMiddleware,
        allow_origins=ALLOWED_ORIGINS,
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )


def _setup_routers(app: FastAPI):
    """Register routers with the application.

    Args:
        app: FastAPI application instance
    """
    app.include_router(root_router)
    app.include_router(models_router)


def get_hf_service():
    """Get the global HuggingFaceService instance.

    Returns:
        HuggingFaceService instance or None if not initialized
    """
    return hf_service


def set_hf_service(service):
    """Set the global HuggingFaceService instance.

    Args:
        service: HuggingFaceService instance
    """
    global hf_service
    hf_service = service

