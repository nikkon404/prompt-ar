# PromptAR

Generate 3D objects from text prompts and visualize them in Augmented Reality using your phone.

## Description

PromptAR is an innovative application that combines AI-powered 3D model generation with Augmented Reality visualization. Simply describe what you want to see, and the app will generate a 3D model that you can place and interact with in your real-world environment through your phone's camera.

## Tech Stack

- **Frontend**: Flutter (Cross-platform mobile app)
- **Backend**: Python FastAPI (REST API server)

## Features

- 🎨 **Text-to-3D Generation**: Convert text descriptions into 3D models
- 📱 **AR Visualization**: View and interact with generated models in Augmented Reality
- 🚀 **Two Generation Modes**:
  - **Basic Mode**: Uses Shap-E model for faster, simpler 3D model generation
  - **Advanced Mode**: Uses TRELLIS model for higher quality 3D models with textures
- 📦 **GLB Format**: Models are generated in GLB format, optimized for AR applications
- 🌐 **Cross-platform**: Works on both iOS and Android devices

## Architecture

### Frontend (Flutter)
- Built with Flutter for cross-platform mobile development
- Uses AR Flutter Plugin for AR visualization
- BLoC pattern for state management
- Camera integration for AR experience

### Backend (Python FastAPI)
- FastAPI REST API server
- Integrates with Hugging Face Spaces for 3D model generation
- Two model options:
  - **Shap-E** (Basic): Faster generation, simpler geometry
  - **TRELLIS** (Advanced): Higher quality with textures, more detailed models
- Model storage and management
- AR-optimized material processing

## Setup

### Backend Setup

1. Navigate to the backend directory:
```bash
cd backend
```

2. Create a virtual environment:
```bash
python -m venv venv
source venv/bin/activate  # On macOS/Linux
# or
venv\Scripts\activate  # On Windows
```

3. Install dependencies:
```bash
pip install -r requirements.txt
```

4. Configure Hugging Face Token:
   - Get your token from https://huggingface.co/settings/tokens (free account works)
   - Create a `.env` file in the `backend` directory:
   ```bash
   HF_TOKEN=your_huggingface_token_here
   ```

5. Run the server:
```bash
python main.py
# or
uvicorn main:app --reload
```

The API will be available at `http://localhost:8000`
API documentation: `http://localhost:8000/docs`

### Frontend Setup

1. Navigate to the frontend directory:
```bash
cd frontend_prompt_ar
```

2. Install dependencies:
```bash
flutter pub get
```

3. Configure environment:
   - Create a `.env` file in the `frontend_prompt_ar` directory:
   ```bash
   BACKEND_URL=http://your-backend-url:8000
   ```

4. Run the app:
```bash
flutter run
```

## API Endpoints

### POST `/api/models/generate`
Generate a 3D model from a text prompt.

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

### GET `/api/models/download/{model_id}`
Download a generated 3D model file (GLB format).

## Model Generation

The backend supports two text-to-3D generation modes:

### Basic Mode (Shap-E)
- **Model**: Shap-E
- **Speed**: Faster generation (5-10 seconds)
- **Quality**: Simpler geometry, basic models
- **Use Case**: Quick prototyping, simple objects

### Advanced Mode (TRELLIS)
- **Model**: TRELLIS (Microsoft)
- **Speed**: Slower generation (10-30 seconds)
- **Quality**: Higher quality with textures and detailed geometry
- **Use Case**: Production-ready models, detailed objects

## Project Structure

```
prompt_ar/
├── backend/                 # Python FastAPI backend
│   ├── main.py             # Application entry point
│   ├── config.py           # Configuration settings
│   ├── routers/            # API route handlers
│   ├── services/           # Business logic
│   │   ├── huggingface_service.py  # Model generation service
│   │   ├── storage_service.py      # Model storage management
│   │   └── ar_material_service.py  # AR material processing
│   ├── schemas/            # Pydantic models
│   └── models/             # Generated 3D model storage
│
└── frontend_prompt_ar/     # Flutter frontend
    ├── lib/
    │   ├── screens/        # UI screens
    │   ├── bloc/           # State management
    │   ├── models/         # Data models
    │   ├── services/       # API services
    │   └── repositories/   # Data repositories
    └── assets/             # App assets
```

## Requirements

### Backend
- Python 3.11+
- FastAPI
- Hugging Face account (free)
- Hugging Face token

### Frontend
- Flutter SDK 3.5.3+
- iOS 12+ or Android API 21+
- Device with AR support

## License

CC0-1.0 License - See LICENSE file for details

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## Acknowledgments

- [TRELLIS](https://huggingface.co/spaces/dkatz2391/TRELLIS_TextTo3D_Try2) - Advanced 3D model generation
- [Shap-E](https://github.com/openai/shap-e) - Basic 3D model generation
- [Hugging Face](https://huggingface.co/) - Model hosting and inference

