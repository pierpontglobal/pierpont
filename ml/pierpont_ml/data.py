from __future__ import annotations

import hashlib
from pathlib import Path
from urllib.request import Request, urlopen

import numpy as np
import pandas as pd

SOURCE_URL = "https://forcar.org/datasets/used-car-prices-by-model-year.csv"
ATTRIBUTION = "Used-car asking prices by ForCar (https://forcar.org/open-data/), CC BY 4.0"
REFERENCE_YEAR = 2026


def download(dest: Path, url: str = SOURCE_URL) -> Path:
    dest.parent.mkdir(parents=True, exist_ok=True)
    req = Request(url, headers={"User-Agent": "pierpont-ml/0.1"})
    with urlopen(req, timeout=60) as r:
        dest.write_bytes(r.read())
    return dest


def fingerprint(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()[:12]


def load(path: Path) -> pd.DataFrame:
    df = pd.read_csv(path, encoding="utf-8-sig")
    df = df.rename(columns={"model_year": "year", "avg_price_usd": "price", "avg_mileage": "mileage"})
    df = df[(df.listings >= 3) & df.price.between(500, 400_000) & df.mileage.between(0, 400_000)]
    df = df.dropna(subset=["make", "model", "year", "price", "mileage"])
    df["make"] = df.make.str.strip()
    df["model"] = df.model.str.strip()
    return df.reset_index(drop=True)


def features(make, model, year, mileage, categories: dict[str, list[str]] | None = None) -> pd.DataFrame:
    df = pd.DataFrame({
        "make": pd.Series(make, dtype="string"),
        "make_model": pd.Series(make, dtype="string") + "|" + pd.Series(model, dtype="string"),
        "age": REFERENCE_YEAR - np.asarray(year, dtype=float),
        "log_mileage": np.log1p(np.asarray(mileage, dtype=float)),
    })
    df["miles_per_year"] = np.expm1(df.log_mileage) / np.maximum(df.age, 0.5)
    for col in ("make", "make_model"):
        cats = categories[col] if categories else sorted(df[col].dropna().unique())
        df[col] = pd.Categorical(df[col].where(df[col].isin(cats)), categories=cats)
    return df
