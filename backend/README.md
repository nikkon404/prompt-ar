# PromptAR Backend

FastAPI server for 3D model generation from text prompts using TRELLIS and Shap-E.

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
   
   **The server will start without HF_TOKEN, but model generation will fail!**

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
Generate a 3D model from a text prompt.

**Request body:**
```json
{
  "prompt": "wooden chair",
  "mode": "advanced"
}
```

**Mode options:**
- `"basic"`: Uses Shap-E for 3D model generation (faster, simpler)
- `"advanced"`: Uses TRELLIS for 3D model generation with textures (higher quality)

**Response:**
```json
{
  "status": "success",
  "message": "3D model generated successfully using advanced mode",
  "model_id": "abc123-456def-789ghi",
  "download_url": "/api/models/download/abc123-456def-789ghi"
}
```

**How it works:**
1. Receives text prompt (e.g., "wooden chair") and mode
2. Uses TRELLIS (advanced) or Shap-E (basic) via Hugging Face Spaces to generate a 3D model
3. Model is generated in GLB format with textures (TRELLIS) or basic geometry (Shap-E)
4. Stores the model locally and returns download URL
5. Model is served via the download endpoint

**Note:** 
- HF_TOKEN is required for model generation
- Uses free Hugging Face Spaces (may have queue times during peak usage)
- Generation typically takes 10-30 seconds (TRELLIS) or 5-10 seconds (Shap-E)
- Spaces may be sleeping (free tier) - they wake up automatically on first use

#### GET `/api/models/download/{model_id}`
Download a generated 3D model file (GLB format).

**Features:**
- Applies brightness normalization for AR visibility
- Returns normalized GLB file as single binary
- Automatic cleanup after download

Returns the generated `.glb` file for use in AR applications.

## Architecture

The backend follows a modular architecture:

- **Schemas** (`schemas/`): Define request/response models using Pydantic
- **Routers** (`routers/`): Handle HTTP requests and route them to services
- **Services** (`services/`): Contain business logic and data management
  - `huggingface_service.py`: Handles TRELLIS and Shap-E integration via Gradio Client
  - `storage_service.py`: Manages model storage and metadata
  - `ar_material_service.py`: Applies brightness normalization for AR visibility
- **Config** (`config.py`): Centralized configuration settings

### 3D Model Generation

The backend supports two text-to-3D generation modes:

**Advanced Mode (TRELLIS):**
- **Model**: TRELLIS (Microsoft)
- **Space**: `dkatz2391/TRELLIS_TextTo3D_Try2` (free, hosted on Hugging Face)
- **Format**: GLB with textures and colors
- **Speed**: ~10-30 seconds per generation
- **Quality**: High-quality textured models optimized for AR

**Basic Mode (Shap-E):**
- **Model**: OpenAI's Shap-E
- **Space**: `hysts/Shap-E` (free, hosted on Hugging Face)
- **Format**: GLB (basic geometry)
- **Speed**: ~5-10 seconds per generation
- **Quality**: Fast generation with basic geometry

### Client Initialization

The service includes retry logic with exponential backoff for client initialization:
- Retries up to 3 times if initialization fails
- Exponential backoff delays (5s, 10s)
- Non-blocking: Service starts even if clients fail to initialize
- Spaces wake up automatically when first used

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

Generated 3D models are stored in the `models/` directory (default). Each model is saved as a `.glb` file with a unique UUID filename. Models are automatically cleaned up after download to save storage space.

## Dependencies

Key dependencies:
- `fastapi`: Web framework
- `gradio_client`: For interacting with Hugging Face Spaces
- `uvicorn`: ASGI server
- `pydantic`: Data validation
- `python-dotenv`: Environment variable management
- `httpx`: HTTP client for downloading models

See `requirements.txt` for the complete list.
