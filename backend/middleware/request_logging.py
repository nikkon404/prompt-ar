"""Middleware for logging all API requests to SQLite database."""

import logging
from fastapi import Request
from starlette.middleware.base import BaseHTTPMiddleware
from middleware.utils import get_client_ip

logger = logging.getLogger(__name__)


class RequestLoggingMiddleware(BaseHTTPMiddleware):
    """Middleware to log all API requests to SQLite database immediately on receipt."""

    def __init__(self, app, database_service):
        """Initialize the middleware.

        Args:
            app: FastAPI application instance
            database_service: DatabaseService instance for logging requests
        """
        super().__init__(app)
        self.database_service = database_service

    async def dispatch(self, request: Request, call_next):
        """Log the request immediately when received, then process it.

        Args:
            request: FastAPI request object
            call_next: Next middleware/handler in the chain

        Returns:
            Response object
        """
        # Get client IP address
        client_ip = get_client_ip(request)

        # Get user agent
        user_agent = request.headers.get("user-agent")

        # Log the request immediately when received (before processing)
        try:
            self.database_service.log_request(
                method=request.method,
                path=request.url.path,
                client_ip=client_ip,
                user_agent=user_agent,
            )
        except Exception as e:
            # Don't fail the request if logging fails
            logger.error(f"Failed to log request: {e}")

        # Process the request
        response = await call_next(request)
        return response

