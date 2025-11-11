# Prompt AR

<div align="center">
  <img src="logo.png" alt="Prompt AR Logo" width="200"/>
  
  **Generate 3D objects from text prompts and visualize them in Augmented Reality**
  
  [![Flutter](https://img.shields.io/badge/Flutter-3.5.3+-02569B?logo=flutter)](https://flutter.dev/)
  [![Python](https://img.shields.io/badge/Python-3.11+-3776AB?logo=python)](https://www.python.org/)
  [![FastAPI](https://img.shields.io/badge/FastAPI-0.104+-009688?logo=fastapi)](https://fastapi.tiangolo.com/)
  [![License](https://img.shields.io/badge/License-CC0--1.0-lightgrey)](LICENSE)
</div>

---

## 🎯 Overview

**Prompt AR** is an innovative mobile application that combines the power of AI-driven 3D model generation with immersive Augmented Reality visualization. Simply describe what you want to see in natural language, and watch as the app generates a 3D model that you can place, interact with, and explore in your real-world environment through your phone's camera.

### Key Highlights

- 🤖 **AI-Powered Generation**: Leverages cutting-edge text-to-3D models (Shap-E and TRELLIS)
- 📱 **AR Visualization**: Real-time Augmented Reality placement and interaction
- 🎨 **Two Quality Modes**: Choose between fast basic generation or high-quality advanced models
- 🌐 **Cross-Platform**: Native iOS and Android support
- ⚡ **Real-Time**: Generate and visualize 3D models in seconds

## ✨ Features

- 🎨 **Text-to-3D Generation**: Convert text descriptions into 3D models using state-of-the-art AI models
- 📱 **AR Visualization**: View and interact with generated models in Augmented Reality
- 🚀 **Dual Generation Modes**:
  - **Basic Mode**: Uses Shap-E model for faster, simpler 3D model generation (5-10 seconds)
  - **Advanced Mode**: Uses TRELLIS model for higher quality 3D models with textures (10-30 seconds)
- 📦 **GLB Format**: Models are generated in GLB format, optimized for AR applications
- 🎯 **Plane Detection**: Automatically detects horizontal and vertical surfaces for model placement
- 🖱️ **Interactive Controls**: Pan, rotate, and scale models in AR space
- 💾 **Model Management**: Save and reuse generated models
- 🌐 **Cross-platform**: Works seamlessly on both iOS and Android devices

## 🏗️ Architecture

### Frontend (Flutter)
- **Framework**: Flutter for cross-platform mobile development
- **AR Engine**: AR Flutter Plugin 2 (ARCore for Android, ARKit for iOS)
- **State Management**: BLoC pattern for reactive state management
- **Architecture**: Clean architecture with separation of concerns
- **Features**:
  - Camera integration for AR experience
  - Real-time model loading and rendering
  - Gesture-based model manipulation
  - Error handling and loading states

### Backend (Python FastAPI)
- **Framework**: FastAPI REST API server
- **AI Integration**: Hugging Face Spaces API for 3D model generation
- **Model Options**:
  - **Shap-E** (Basic): Faster generation, simpler geometry
  - **TRELLIS** (Advanced): Higher quality with textures, more detailed models
- **Features**:
  - Model storage and management
  - AR-optimized material processing
  - Async request handling
  - Health check endpoints

## 🚀 Quick Start

### Prerequisites

- **Backend**: Python 3.11+, Hugging Face account (free)
- **Frontend**: Flutter SDK 3.5.3+, iOS 12+ or Android API 21+
- **Device**: iOS or Android device with AR support (ARCore/ARKit)

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
   - Get your token from [Hugging Face Settings](https://huggingface.co/settings/tokens) (free account works)
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
   - For local development, use: `BACKEND_URL=http://localhost:8000`
   - For Android emulator, use: `BACKEND_URL=http://10.0.2.2:8000`
   - For iOS simulator, use: `BACKEND_URL=http://localhost:8000`

4. Run the app:
```bash
flutter run
```

## 📡 API Endpoints

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

### GET `/health`
Health check endpoint to verify backend connectivity.

## 🎨 Model Generation

The backend supports two text-to-3D generation modes:

### Basic Mode (Shap-E)
- **Model**: [Shap-E](https://github.com/openai/shap-e) by OpenAI
- **Speed**: Faster generation (5-10 seconds)
- **Quality**: Simpler geometry, basic models
- **Use Case**: Quick prototyping, simple objects, rapid iteration

### Advanced Mode (TRELLIS)
- **Model**: [TRELLIS](https://huggingface.co/spaces/dkatz2391/TRELLIS_TextTo3D_Try2) by Microsoft
- **Speed**: Slower generation (10-30 seconds)
- **Quality**: Higher quality with textures and detailed geometry
- **Use Case**: Production-ready models, detailed objects, final presentations

## 📁 Project Structure

```
prompt_ar/
├── backend/                 # Python FastAPI backend
│   ├── main.py             # Application entry point
│   ├── config.py           # Configuration settings
│   ├── routers/            # API route handlers
│   │   ├── models.py       # Model generation endpoints
│   │   └── root.py         # Root/health endpoints
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
    │   │   ├── welcome/    # Welcome/permission screen
    │   │   └── ar_view/    # AR visualization screen
    │   ├── bloc/           # State management (BLoC pattern)
    │   │   └── ar_bloc/    # AR-specific state management
    │   ├── models/         # Data models
    │   ├── services/       # API services
    │   └── repositories/   # Data repositories
    ├── assets/             # App assets (3D models, etc.)
    ├── android/            # Android-specific configuration
    └── ios/                # iOS-specific configuration
```

## 🔧 Requirements

### Backend
- Python 3.11+
- FastAPI
- Hugging Face account (free)
- Hugging Face token

### Frontend
- Flutter SDK 3.5.3+
- iOS 12+ or Android API 21+
- Device with AR support:
  - **Android**: ARCore-compatible device
  - **iOS**: Device with ARKit support (iPhone 6s or newer, iPad Pro, etc.)

## 📱 Platform Support

### Android
- Requires ARCore support
- Minimum API level: 21
- Recommended: API 30+ for best performance
- Adaptive icons supported

### iOS
- Requires ARKit support
- Minimum iOS version: 12.0
- Recommended: iOS 14+ for best performance
- Supports iPhone and iPad

## 🎯 Use Cases

- **Education**: Visualize 3D concepts in AR for learning
- **Design**: Quick prototyping and visualization of design ideas
- **Entertainment**: Create and interact with 3D objects in your environment
- **E-commerce**: Preview products in AR before purchase
- **Architecture**: Visualize architectural concepts in real spaces

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request. For major changes, please open an issue first to discuss what you would like to change.

## 📄 License

This project is licensed under the CC0-1.0 License - See [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- [TRELLIS](https://huggingface.co/spaces/dkatz2391/TRELLIS_TextTo3D_Try2) - Advanced 3D model generation by Microsoft
- [Shap-E](https://github.com/openai/shap-e) - Basic 3D model generation by OpenAI
- [Hugging Face](https://huggingface.co/) - Model hosting and inference platform
- [AR Flutter Plugin](https://github.com/nikkon404/ar_flutter_plugin_2) - AR visualization framework

## 📞 Support

For issues, questions, or contributions, please open an issue on the GitHub repository.

---

<div align="center">
  Made with ❤️ using Flutter and FastAPI
</div>
