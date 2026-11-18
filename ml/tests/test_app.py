import os
from pathlib import Path

import pytest
from fastapi.testclient import TestClient

ROOT = Path(__file__).resolve().parents[1]
VISION = Path(os.environ.get("VISION_DIR", ROOT / "models" / "vision"))
pytestmark = pytest.mark.skipif(not (VISION / "vision.json").exists(), reason="vision export not present")


@pytest.fixture(scope="module")
def client(models_dir):
    os.environ["MODELS_DIR"] = str(models_dir)
    os.environ["VISION_DIR"] = str(VISION)
    from pierpont_ml.app import app

    with TestClient(app) as c:
        yield c


def test_price(client):
    r = client.post("/v1/price", json={"make": "Honda", "model": "Civic", "year": 2019, "mileage": 60000})
    assert r.status_code == 200 and r.json()["estimate_usd"] > 1000


def test_price_validation(client):
    assert client.post("/v1/price", json={"make": "Honda", "model": "Civic", "year": 1900, "mileage": 1}).status_code == 422


def test_vision_on_car_photo(client):
    with open(ROOT / "samples" / "car-02.jpg", "rb") as f:
        r = client.post("/v1/vision", files={"image": ("car.jpg", f, "image/jpeg")})
    body = r.json()
    assert r.status_code == 200 and body["is_vehicle"]
    assert body["body_style"][0]["label"] == "pickup truck"


def test_vision_rejects_garbage(client):
    r = client.post("/v1/vision", files={"image": ("x.jpg", b"not an image", "image/jpeg")})
    assert r.status_code == 422


def test_metrics_and_models(client):
    client.post("/v1/price", json={"make": "Ford", "model": "F-150", "year": 2018, "mileage": 90000})
    assert "pierpont_ml_price_model_info" in client.get("/metrics").text
    assert client.get("/v1/models").json()["price"]["metrics"]["mape"] > 0
