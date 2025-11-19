---
title: PromptAR Backend API
emoji: 🎨
colorFrom: blue
colorTo: purple
sdk: docker
pinned: false
license: mit
app_port: 7860
---

# PromptAR Backend API

FastAPI backend for generating 3D models from text prompts using AI, optimized for AR applications.

## Features

- 🎨 **Text-to-3D Generation**: Generate 3D models from text prompts using TRELLIS and Shap-E
- 🚀 **Two Generation Modes**: 
  - **Advanced Mode** (TRELLIS): High-quality textured models
  - **Basic Mode** (Shap-E): Fast generation with basic geometry
- 📦 **GLB Format**: Direct export to GLB format optimized for AR
- 🔧 **AR-Optimized**: Automatic brightness normalization for better AR visibility
- 📊 **Request Logging**: Built-in database for tracking API requests
- 🌐 **CORS Enabled**: Ready for cross-origin requests from mobile and web apps
- 🛡️ **Rate Limiting**: Global rate limiting to prevent API abuse (configurable per IP)

## API Endpoints

The backend API is hosted on Hugging Face Spaces and available at: **[https://xnikkon-prmpt-ar-be.hf.space](https://xnikkon-prmpt-ar-be.hf.space)**

### 🏠 Root Endpoints

- **GET `/`** - API information and status
- **GET `/health`** - Health check endpoint

**Example**: [https://xnikkon-prmpt-ar-be.hf.space/health](https://xnikkon-prmpt-ar-be.hf.space/health)

### 🎨 Model Generation

- **POST `/api/models/generate`** - Generate a 3D model from text
  
  **Request:**
  ```json
  {
    "prompt": "wooden chair",
    "mode": "basic"  // or "advanced"
  }
  ```
  
  **Response:**
  ```json
  {
    "status": "success",
    "message": "3D model generated successfully using basic mode",
    "model_id": "abc123-456def-789ghi",
    "download_url": "/api/models/download/abc123-456def-789ghi"
  }
  ```
  
  **Mode Options:**
  - `"basic"`: Uses Shap-E for faster, simpler 3D model generation
  - `"advanced"`: Uses TRELLIS for higher quality 3D models with textures

- **GET `/api/models/download/{model_id}`** - Download generated model (GLB format)

## Usage

### API Documentation

Once deployed, visit:
- Interactive docs: `https://your-space-url.hf.space/docs`
- Alternative docs: `https://your-space-url.hf.space/redoc`

### Example Request

```bash
curl -X POST "https://your-space-url.hf.space/api/models/generate" \
  -H "Content-Type: application/json" \
  -d '{"prompt": "a red sports car", "mode": "advanced"}'
```

### Response

```json
{
  "status": "success",
  "message": "3D model generated successfully using advanced mode",
  "model_id": "abc123-456def-789ghi",
  "download_url": "/api/models/download/abc123-456def-789ghi"
}
```

## Configuration

The backend uses environment variables for configuration. In Hugging Face Spaces, set these in the **Settings > Repository Secrets**:

### Required
- `HF_TOKEN` - Your Hugging Face API token (get it from [Settings](https://huggingface.co/settings/tokens))

### Optional
- `ALLOWED_ORIGINS` - CORS allowed origins (default: "*")
- `MODEL_STORAGE_PATH` - Path for storing models (default: "./models")
- `RATE_LIMIT_REQUESTS` - Maximum requests per time window (default: "5")
- `RATE_LIMIT_WINDOW_SECONDS` - Time window in seconds for rate limiting (default: "60")

### Rate Limiting

The API has global rate limiting enabled to prevent abuse. By default, each IP address is limited to **5 requests per 60 seconds** across all endpoints. When the limit is exceeded, the API returns a `429 Too Many Requests` status with a `Retry-After` header indicating when to retry.

You can configure the rate limits using environment variables:
- `RATE_LIMIT_REQUESTS`: Number of requests allowed (default: 5)
- `RATE_LIMIT_WINDOW_SECONDS`: Time window in seconds (default: 60)

Example: To allow 10 requests per minute, set `RATE_LIMIT_REQUESTS=10` and `RATE_LIMIT_WINDOW_SECONDS=60`.

## Architecture

The backend is built with:
- **FastAPI**: Modern Python web framework
- **Gradio Client**: Integration with HF Spaces (TRELLIS, Shap-E)
- **Pydantic**: Data validation
- **SQLite**: Request logging database
- **pygltflib**: 3D model processing

### Project Structure

```
backend/
├── app/                    # Application factory
│   └── app.py             # FastAPI app creation
├── routers/               # API route handlers
│   ├── root.py           # Root endpoints
│   └── models.py         # Model generation endpoints
├── services/             # Business logic
│   ├── huggingface_service.py   # AI model integration
│   ├── storage_service.py       # Model storage
│   ├── ar_material_service.py   # AR optimization
│   └── database_service.py      # Request logging
├── schemas/              # Request/response models
├── middleware/           # Custom middleware
├── utils/               # Utilities
├── config.py            # Configuration
└── main.py             # Entry point
```

## 3D Model Generation

The backend supports two text-to-3D generation modes:

### Advanced Mode (TRELLIS)
- **Model**: [TRELLIS](https://huggingface.co/spaces/dkatz2391/TRELLIS_TextTo3D_Try2) by Microsoft
- **Speed**: Slower generation (10-30 seconds)
- **Quality**: Higher quality with textures and detailed geometry
- **Use Case**: Production-ready models, detailed objects, final presentations
- Optimized for AR applications

### Basic Mode (Shap-E)
- **Model**: [Shap-E](https://github.com/openai/shap-e) by OpenAI
- **Speed**: Faster generation (5-10 seconds)
- **Quality**: Simpler geometry, basic models
- **Use Case**: Quick prototyping, simple objects, rapid iteration

## Development

To run locally:

```bash
# Install dependencies
pip install -r requirements.txt

# Set environment variables
export HF_TOKEN=your_token_here

# Run the server
python main.py
```

Visit `http://localhost:8000/docs` for API documentation.

## License

MIT License - See LICENSE file for details

## Links

- 🏠 [Project Repository](https://github.com/nikkon404/prompt-ar)
- 📱 [Flutter Frontend](https://github.com/nikkon404/prompt-ar/tree/main/frontend_prompt_ar)
- 📖 [Full Documentation](https://github.com/nikkon404/prompt-ar/blob/main/README.md)
- 🌐 [Live API](https://xnikkon-prmpt-ar-be.hf.space)
- 📚 [API Documentation](https://xnikkon-prmpt-ar-be.hf.space/docs)

