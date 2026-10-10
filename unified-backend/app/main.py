"""
Bell Pepper Plant Health - Unified Backend.

Single FastAPI process loading all four component models directly
(RGB, Thermal, Environmental = trained artifacts under app/models/;
Adaptive = deterministic rule engine, no model file) and exposing one set
of REST endpoints for the mobile app.

Run with (from the unified-backend/ directory):
    uvicorn app.main:app --reload --port 8000
"""

from __future__ import annotations

from contextlib import asynccontextmanager

from fastapi import FastAPI

from app.routes import adaptive, analyze, environmental, rgb, thermal
from app.services import environmental_service, rgb_service, thermal_service


@asynccontextmanager
async def lifespan(app: FastAPI):
    rgb_service.load_artifacts()
    thermal_service.load_artifacts()
    environmental_service.load_artifacts()
    yield


app = FastAPI(title="Bell Pepper Plant Health - Unified Backend", lifespan=lifespan)

app.include_router(rgb.router)
app.include_router(thermal.router)
app.include_router(environmental.router)
app.include_router(adaptive.router)
app.include_router(analyze.router)


@app.get("/health")
def health() -> dict:
    return {
        "rgb": rgb_service.artifacts_ready(),
        "thermal": thermal_service.artifacts_ready(),
        "environmental": environmental_service.artifacts_ready(),
        "adaptive": True,
    }
