"""Global rate limiting middleware - configurable requests per minute per IP."""

import logging
import time
from collections import defaultdict, deque
from fastapi import Request, HTTPException, status
from starlette.middleware.base import BaseHTTPMiddleware

from config import RATE_LIMIT_REQUESTS, RATE_LIMIT_WINDOW_SECONDS
from middleware.utils import get_client_ip

logger = logging.getLogger(__name__)


class GlobalRateLimitMiddleware(BaseHTTPMiddleware):
    """Global rate limiting: configurable requests per time window per IP."""

    def __init__(self, app):
        super().__init__(app)
        self.max_requests = RATE_LIMIT_REQUESTS
        self.window_seconds = RATE_LIMIT_WINDOW_SECONDS
        self.request_history: dict[str, deque] = defaultdict(lambda: deque())
        logger.info(
            f"Global rate limit: {self.max_requests} requests per {self.window_seconds} seconds"
        )

    async def dispatch(self, request: Request, call_next):
        """Apply rate limiting to all requests."""
        ip = get_client_ip(request)

        # Skip rate limiting if IP is unknown
        if ip == "unknown":
            return await call_next(request)

        now = time.time()
        cutoff = now - self.window_seconds

        # Clean up old requests outside the window
        history = self.request_history[ip]
        while history and history[0] < cutoff:
            history.popleft()

        # Check if limit exceeded
        if len(history) >= self.max_requests:
            logger.warning(f"Rate limit exceeded for {ip} on {request.url.path}")
            raise HTTPException(
                status_code=status.HTTP_429_TOO_MANY_REQUESTS,
                detail=f"Rate limit exceeded: {self.max_requests} requests per {self.window_seconds} seconds.",
                headers={"Retry-After": str(self.window_seconds)},
            )

        # Add current request timestamp
        history.append(now)

        # Process the request
        return await call_next(request)
