from __future__ import annotations

import json
import threading
from pathlib import Path

import lightgbm as lgb
import numpy as np

from . import data


class PriceModel:
    """Loads models/current and reloads it when a retrain promotes a new version."""

    def __init__(self, root: Path):
        self.root = root
        self.lock = threading.Lock()
        self.version = None
        self.reload()

    def reload(self) -> bool:
        card_path = self.root / "current" / "card.json"
        card = json.loads(card_path.read_text())
        if card["version"] == self.version:
            return False
        booster = lgb.Booster(model_file=str(self.root / "current" / "price.txt"))
        with self.lock:
            self.card, self.booster, self.version = card, booster, card["version"]
            self.models_by_make: dict[str, list[str]] = {}
            for mm in card["categories"]["make_model"]:
                make, model = mm.split("|", 1)
                self.models_by_make.setdefault(make, []).append(model)
        return True

    def estimate(self, make: str, model: str, year: int, mileage: int) -> dict:
        with self.lock:
            cats, booster, card = self.card["categories"], self.booster, self.card
        x = data.features([make], [model], [year], [mileage], cats)
        mu = float(booster.predict(x)[0])
        q = card["metrics"]["interval_log_halfwidth"]
        return {
            "estimate_usd": round(float(np.exp(mu)), -1),
            "low_usd": round(float(np.exp(mu - q)), -1),
            "high_usd": round(float(np.exp(mu + q)), -1),
            "known_model": f"{make}|{model}" in cats["make_model"],
            "model_version": card["version"],
        }
