"""Main application entry point for PromptAR Backend API."""

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from routers import models_router, root_router
from config import API_TITLE, API_DESCRIPTION, API_VERSION, ALLOWED_ORIGINS

# Initialize FastAPI application
app = FastAPI(title=API_TITLE, description=API_DESCRIPTION, version=API_VERSION)

# Configure CORS (needed for Flutter web and mobile apps)
app.add_middleware(
    CORSMiddleware,
    allow_origins=ALLOWED_ORIGINS,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Include routers
app.include_router(root_router)
app.include_router(models_router)


if __name__ == "__main__":
    import uvicorn
    from config import HOST, PORT

    uvicorn.run(app, host=HOST, port=PORT)
