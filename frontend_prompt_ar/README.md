# Prompt AR - Flutter Frontend

Flutter mobile application for Prompt AR - Generate 3D objects from text prompts and visualize them in Augmented Reality.

## Getting Started

### Prerequisites

- Flutter SDK 3.5.3+
- Dart SDK
- iOS 12+ or Android API 21+
- Device with AR support (ARCore for Android, ARKit for iOS)

### Environment Configuration

**⚠️ Important**: This app requires a `.env` file to be configured before running.

1. Create a `.env` file in the `frontend_prompt_ar` directory (same level as `pubspec.yaml`)

2. Add the following configuration:

```bash
# Backend API URL (required)
# Use the hosted backend on Hugging Face Spaces
BACKEND_BASE_URL=https://xnikkon-prmpt-ar-be.hf.space

# Optional: Configure timeouts (in seconds)
# GENERATION_TIMEOUT=600
# DOWNLOAD_TIMEOUT=300
```

**Note**: The backend is hosted on Hugging Face Spaces. If you're running a local backend for development, you can change the URL:
- Local development: `BACKEND_BASE_URL=http://localhost:8000`

### Installation

1. Install Flutter dependencies:
```bash
flutter pub get
```

2. Ensure the `.env` file is properly configured (see above)

3. Run the app:
```bash
flutter pub get
flutter run
```

## Project Structure

```
lib/
├── screens/          # UI screens
│   ├── welcome/     # Welcome/permission screen
│   └── ar_view/     # AR visualization screen
├── bloc/            # State management (BLoC pattern)
│   └── ar_bloc/     # AR-specific state management
├── models/          # Data models
├── services/        # API services
└── repositories/    # Data repositories
```

## Features

- 🎨 Text-to-3D model generation
- 📱 Augmented Reality visualization
- 🎯 Plane detection for model placement
- 🖱️ Interactive model manipulation (pan, rotate, scale)
- 💾 Model management and storage

## Backend API

The app connects to the backend API hosted on Hugging Face Spaces:
- **API URL**: [https://xnikkon-prmpt-ar-be.hf.space](https://xnikkon-prmpt-ar-be.hf.space)
- **API Docs**: [https://xnikkon-prmpt-ar-be.hf.space/docs](https://xnikkon-prmpt-ar-be.hf.space/docs)


## Resources

- [Flutter Documentation](https://docs.flutter.dev/)
- [AR Flutter Plugin](https://github.com/nikkon404/ar_flutter_plugin_2)
