"""Database service for SQLite operations to store API request logs."""

import sqlite3
import logging
from datetime import datetime, timezone
from pathlib import Path
from typing import Optional, Dict, Any
from contextlib import contextmanager

logger = logging.getLogger(__name__)


class DatabaseService:
    """Service for managing SQLite database operations for API request logging."""

    def __init__(self, db_path: str = "api_requests.db"):
        """Initialize the database service.

        Args:
            db_path: Path to the SQLite database file
        """
        self.db_path = Path(db_path)
        self._ensure_db_directory()
        self._initialize_database()

    def _ensure_db_directory(self):
        """Ensure the directory for the database file exists."""
        self.db_path.parent.mkdir(parents=True, exist_ok=True)

    def _initialize_database(self):
        """Initialize the database and create tables if they don't exist."""
        try:
            with self._get_connection() as conn:
                cursor = conn.cursor()
                cursor.execute(
                    """
                    CREATE TABLE IF NOT EXISTS api_requests (
                        id INTEGER PRIMARY KEY AUTOINCREMENT,
                        timestamp_utc TEXT NOT NULL,
                        method TEXT NOT NULL,
                        path TEXT NOT NULL,
                        client_ip TEXT,
                        user_agent TEXT,
                        created_at TEXT NOT NULL DEFAULT (datetime('now', 'utc'))
                    )
                """
                )

                # Create index on timestamp for faster queries
                cursor.execute(
                    """
                    CREATE INDEX IF NOT EXISTS idx_timestamp_utc 
                    ON api_requests(timestamp_utc)
                """
                )

                # Create index on client_ip for faster queries
                cursor.execute(
                    """
                    CREATE INDEX IF NOT EXISTS idx_client_ip 
                    ON api_requests(client_ip)
                """
                )

                conn.commit()
                logger.info(f"✓ Database initialized: {self.db_path}")
        except Exception as e:
            logger.error(f"Failed to initialize database: {e}")
            raise

    @contextmanager
    def _get_connection(self):
        """Get a database connection with proper error handling."""
        conn = None
        try:
            conn = sqlite3.connect(str(self.db_path), timeout=10.0)
            conn.row_factory = sqlite3.Row  # Return rows as dictionaries
            yield conn
        except sqlite3.Error as e:
            logger.error(f"Database error: {e}")
            if conn:
                conn.rollback()
            raise
        finally:
            if conn:
                conn.close()

    def log_request(
        self,
        method: str,
        path: str,
        client_ip: Optional[str] = None,
        user_agent: Optional[str] = None,
    ):
        """Log an API request to the database immediately when received.

        Args:
            method: HTTP method (GET, POST, etc.)
            path: Request path
            client_ip: Client IP address
            user_agent: User agent string
        """
        try:
            # Get UTC timestamp
            timestamp_utc = datetime.now(timezone.utc).isoformat()

            with self._get_connection() as conn:
                cursor = conn.cursor()
                cursor.execute(
                    """
                    INSERT INTO api_requests 
                    (timestamp_utc, method, path, client_ip, user_agent)
                    VALUES (?, ?, ?, ?, ?)
                """,
                    (
                        timestamp_utc,
                        method,
                        path,
                        client_ip,
                        user_agent,
                    ),
                )
                conn.commit()
        except Exception as e:
            # Log error but don't fail the request
            logger.error(f"Failed to log request to database: {e}")

    def get_requests(
        self,
        limit: int = 100,
        offset: int = 0,
        client_ip: Optional[str] = None,
        method: Optional[str] = None,
    ) -> list[Dict[str, Any]]:
        """Get API requests from the database.

        Args:
            limit: Maximum number of requests to return
            offset: Number of requests to skip
            client_ip: Filter by client IP (optional)
            method: Filter by HTTP method (optional)

        Returns:
            List of request dictionaries
        """
        try:
            with self._get_connection() as conn:
                cursor = conn.cursor()

                query = "SELECT * FROM api_requests WHERE 1=1"
                params = []

                if client_ip:
                    query += " AND client_ip = ?"
                    params.append(client_ip)

                if method:
                    query += " AND method = ?"
                    params.append(method)

                query += " ORDER BY timestamp_utc DESC LIMIT ? OFFSET ?"
                params.extend([limit, offset])

                cursor.execute(query, params)
                rows = cursor.fetchall()

                return [dict(row) for row in rows]
        except Exception as e:
            logger.error(f"Failed to get requests from database: {e}")
            return []

    def get_request_count(self, client_ip: Optional[str] = None) -> int:
        """Get total count of requests.

        Args:
            client_ip: Filter by client IP (optional)

        Returns:
            Total count of requests
        """
        try:
            with self._get_connection() as conn:
                cursor = conn.cursor()

                if client_ip:
                    cursor.execute(
                        "SELECT COUNT(*) FROM api_requests WHERE client_ip = ?",
                        (client_ip,),
                    )
                else:
                    cursor.execute("SELECT COUNT(*) FROM api_requests")

                return cursor.fetchone()[0]
        except Exception as e:
            logger.error(f"Failed to get request count from database: {e}")
            return 0
