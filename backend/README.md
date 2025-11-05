# PromptAR Backend

FastAPI server for 3D model generation from text prompts using Shap-E.

## Project Structure

```
backend/
├── main.py                      # Application entry point
├── config.py                    # Configuration settings
├── requirements.txt             # Python dependencies
├── schemas/                     # Pydantic models/schemas
│   ├── __init__.py
│   └── models.py               # Request/Response schemas
├── routers/                     # API route handlers
│   ├── __init__.py
│   ├── root.py                 # Root and health check endpoints
│   └── models.py               # Model generation and download endpoints
└── services/                    # Business logic
    ├── __init__.py
    ├── huggingface_service.py  # Shap-E 3D model generation service
    └── storage_service.py       # Storage/state management
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

3. **Configure Hugging Face Token (Required):**
   
   **The backend requires a Hugging Face token to generate 3D models.**
   
   Get your Hugging Face token from https://huggingface.co/settings/tokens
   (Free account works - no Pro subscription needed)
   
   **Option 1: Using .env file (Recommended)**
   
   Create a `.env` file in the `backend` directory:
   ```bash
   cd backend
   touch .env
   ```
   
   Then edit `.env` and add your token:
   ```bash
   HF_TOKEN=your_huggingface_token_here
   ```
   
   **Option 2: Using environment variable**
   
   ```bash
   export HF_TOKEN=your_huggingface_token_here
   ```
   
   **The server will not start without HF_TOKEN configured!**

## Running the Server

**Option 1: Using Python (Recommended)**
```bash
python main.py
```

**Option 2: Using uvicorn directly**
```bash
uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

**Note:** Make sure you're in the `backend` directory and have activated your virtual environment before running.

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
Generate a 3D model directly from a text prompt using Shap-E.

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

**How it works:**
1. Receives text prompt (e.g., "wooden chair")
2. Uses Shap-E (via Hugging Face Spaces) to generate a 3D model directly from text
3. Model is generated in GLB format (~5-10 seconds)
4. Stores the model locally and returns download URL
5. Model is served via the download endpoint

**Note:** 
- HF_TOKEN is required. The server will fail to start without it.
- Uses free Hugging Face Spaces (may have queue times during peak usage)
- Generation typically takes 5-10 seconds

#### GET `/api/models/download/{model_id}`
Download a generated 3D model file (GLB format).

Returns the generated `.glb` file for use in AR applications.

## Architecture

The backend follows a modular architecture:

- **Schemas** (`schemas/`): Define request/response models using Pydantic
- **Routers** (`routers/`): Handle HTTP requests and route them to services
- **Services** (`services/`): Contain business logic and data management
  - `huggingface_service.py`: Handles Shap-E integration via Gradio Client
  - `storage_service.py`: Manages model storage and metadata
- **Config** (`config.py`): Centralized configuration settings

### 3D Model Generation

The backend uses **Shap-E** (hosted on Hugging Face Spaces) for direct text-to-3D generation:
- **Model**: OpenAI's Shap-E
- **Space**: `hysts/Shap-E` (free, hosted on Hugging Face)
- **Format**: GLB (glTF Binary) - ready for AR/VR applications
- **Speed**: ~5-10 seconds per generation

This separation of concerns makes the codebase:
- Easier to test
- More maintainable
- Scalable for future enhancements

## Configuration

### Environment Variables

Create a `.env` file in the `backend` directory:

```bash
# Required
HF_TOKEN=your_huggingface_token_here

# Optional (defaults shown)
HOST=0.0.0.0
PORT=8000
MODEL_STORAGE_PATH=./models
ALLOWED_ORIGINS=*
```

### Model Storage

Generated 3D models are stored in the `models/` directory (default). Each model is saved as a `.glb` file with a unique UUID filename.

## Dependencies

Key dependencies:
- `fastapi`: Web framework
- `gradio_client`: For interacting with Hugging Face Spaces
- `uvicorn`: ASGI server
- `pydantic`: Data validation
- `python-dotenv`: Environment variable management

See `requirements.txt` for the complete list.