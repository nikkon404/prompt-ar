# PromptAR Backend

FastAPI server for 3D model generation from text prompts.

## Project Structure

```
backend/
├── main.py                 # Application entry point
├── config.py              # Configuration settings
├── requirements.txt       # Python dependencies
├── schemas/               # Pydantic models/schemas
│   ├── __init__.py
│   └── models.py         # Request/Response schemas
├── routers/              # API route handlers
│   ├── __init__.py
│   ├── root.py          # Root and health check endpoints
│   └── models.py        # Model generation and download endpoints
└── services/            # Business logic
    ├── __init__.py
    ├── model_service.py # Model generation service
    └── storage_service.py # Storage/state management
```

## Setup

1. Create a virtual environment:
```bash
python -m venv venv
source venv/bin/activate  # On macOS/Linux
# or
venv\Scripts\activate  # On Windows
```

2. Install dependencies:
```bash
pip install -r requirements.txt
```

## Running the Server

```bash
python main.py
```

Or with uvicorn directly:
```bash
uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

The server will start at `http://localhost:8000`

## API Documentation

Once the server is running, visit:
- Interactive API docs: `http://localhost:8000/docs`
- Alternative docs: `http://localhost:8000/redoc`

## API Endpoints

### Root Endpoints

#### GET `/`
Root endpoint providing API information.

#### GET `/health`
Health check endpoint.

### Model Endpoints

#### POST `/api/models/generate`
Generate a 3D model from a text prompt.

**Request body:**
```json
{
  "prompt": "wooden chair"
}
```

**Response:**
```json
{
  "status": "success",
  "message": "3D model generated successfully",
  "model_id": "abc123-456def-789ghi",
  "download_url": "/api/models/download/abc123-456def-789ghi"
}
```

#### GET `/api/models/download/{model_id}`
Download a generated 3D model file (.glb format).

Returns the generated .glb file.

#### GET `/api/models`
List all generated models (for debugging).

#### GET `/api/models/{model_id}`
Get information about a specific model.

## Architecture

The backend follows a modular architecture:

- **Schemas** (`schemas/`): Define request/response models using Pydantic
- **Routers** (`routers/`): Handle HTTP requests and route them to services
- **Services** (`services/`): Contain business logic and data management
- **Config** (`config.py`): Centralized configuration settings

This separation of concerns makes the codebase:
- Easier to test
- More maintainable
- Scalable for future enhancements