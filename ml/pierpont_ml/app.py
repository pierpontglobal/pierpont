from __future__ import annotations

import asyncio
import os
import shutil
import time
from contextlib import asynccontextmanager
from pathlib import Path

from fastapi import FastAPI, File, HTTPException, Request, UploadFile
from fastapi.responses import Response
from prometheus_client import CONTENT_TYPE_LATEST, Counter, Gauge, Histogram, generate_latest
from pydantic import BaseModel, Field

from .pricing import PriceModel
from .vision import VehicleClassifier

MODELS = Path(os.environ.get("MODELS_DIR", "/models"))
VISION = Path(os.environ.get("VISION_DIR", str(MODELS / "vision")))
RELOAD_SECONDS = int(os.environ.get("RELOAD_SECONDS", "60"))
MAX_UPLOAD = 8 * 2**20
SEED = Path(os.environ.get("SEED_MODELS_DIR", "/opt/models"))

REQUESTS = Counter("pierpont_ml_requests_total", "Requests", ["route", "status"])
LATENCY = Histogram("pierpont_ml_latency_seconds", "Latency", ["route"], buckets=(.005, .01, .025, .05, .1, .25, .5, 1, 2.5))
ESTIMATES = Histogram("pierpont_ml_price_estimate_usd", "Price estimates", buckets=(2e3, 5e3, 1e4, 2e4, 3e4, 5e4, 8e4, 1.5e5))
MODEL_INFO = Gauge("pierpont_ml_price_model_info", "Loaded price model", ["version"])
MODEL_MAPE = Gauge("pierpont_ml_price_model_test_mape", "Test MAPE of the loaded price model")
RELOADS = Counter("pierpont_ml_model_reloads_total", "Price model reloads")


def publish(model: PriceModel):
    MODEL_INFO.clear()
    MODEL_INFO.labels(model.version).set(1)
    MODEL_MAPE.set(model.card["metrics"]["mape"])


async def watch(model: PriceModel):
    while True:
        await asyncio.sleep(RELOAD_SECONDS)
        try:
            if await asyncio.to_thread(model.reload):
                RELOADS.inc()
                publish(model)
        except Exception:
            pass


@asynccontextmanager
async def lifespan(app: FastAPI):
    if not (MODELS / "current" / "card.json").exists() and (SEED / "current").exists():
        shutil.copytree(SEED / "current", MODELS / "current", dirs_exist_ok=True)
    app.state.price = PriceModel(MODELS)
    app.state.vision = VehicleClassifier(VISION, os.environ.get("VISION_VARIANT", "int8"), int(os.environ.get("ORT_THREADS", "2")))
    publish(app.state.price)
    task = asyncio.create_task(watch(app.state.price))
    yield
    task.cancel()


app = FastAPI(title="Pierpont ML", version="1.0.0", lifespan=lifespan)


@app.middleware("http")
async def observe(request: Request, call_next):
    route = request.url.path
    start = time.perf_counter()
    status = 500
    try:
        response = await call_next(request)
        status = response.status_code
        return response
    finally:
        if route.startswith("/v1/"):
            LATENCY.labels(route).observe(time.perf_counter() - start)
            REQUESTS.labels(route, str(status)).inc()


class PriceQuery(BaseModel):
    make: str = Field(min_length=1, max_length=40)
    model: str = Field(min_length=1, max_length=60)
    year: int = Field(ge=1980, le=2027)
    mileage: int = Field(ge=0, le=500_000)


@app.get("/healthz")
def healthz():
    return {"ok": True}


@app.get("/v1/models")
def models(request: Request):
    card = request.app.state.price.card
    return {
        "price": {k: card[k] for k in ("version", "trained_at", "rows", "data", "target", "interval", "metrics")},
        "vision": {"model": request.app.state.vision.meta["model"], "variant": request.app.state.vision.variant},
    }


@app.get("/v1/catalog")
def catalog(request: Request):
    return request.app.state.price.models_by_make


@app.post("/v1/price")
def price(q: PriceQuery, request: Request):
    result = request.app.state.price.estimate(q.make, q.model, q.year, q.mileage)
    ESTIMATES.observe(result["estimate_usd"])
    return result


@app.post("/v1/vision")
async def vision(request: Request, image: UploadFile = File(...)):
    body = await image.read(MAX_UPLOAD + 1)
    if len(body) > MAX_UPLOAD:
        raise HTTPException(413, "image over 8 MB")
    try:
        return await asyncio.to_thread(request.app.state.vision.classify, body)
    except Exception:
        raise HTTPException(422, "not a readable image")


@app.get("/metrics")
def metrics():
    return Response(generate_latest(), media_type=CONTENT_TYPE_LATEST)
