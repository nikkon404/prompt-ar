"""Logging configuration with colored output."""

import logging
import sys


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
        """Format log record with colors."""
        # Get the color for this log level
        color = self.COLORS.get(record.levelname, self.RESET)

        # Format the base message
        log_message = super().format(record)

        # For ERROR and CRITICAL, color the entire message
        if record.levelname in ["ERROR", "CRITICAL"]:
            # Color the whole message, with bold levelname
            levelname_colored = (
                f"{self.BOLD}{color}{record.levelname}{self.RESET}{color}"
            )
            log_message = log_message.replace(record.levelname, levelname_colored)
            log_message = f"{color}{log_message}{self.RESET}"
        else:
            # For other levels, just color the levelname (bold)
            levelname_colored = f"{self.BOLD}{color}{record.levelname}{self.RESET}"
            log_message = log_message.replace(record.levelname, levelname_colored)

        return log_message


def setup_colored_logging():
    """Set up colored logging configuration."""
    # Create console handler
    console_handler = logging.StreamHandler(sys.stdout)
    console_handler.setLevel(logging.INFO)

    # Create formatter with colors
    formatter = ColoredFormatter(
        "%(asctime)s - %(name)s - %(levelname)s - %(message)s",
        datefmt="%Y-%m-%d %H:%M:%S",
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

