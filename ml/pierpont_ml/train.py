"""Train the price model, evaluate it, and promote it if it beats the current one.

python -m pierpont_ml.train --models /models [--data data.csv]
"""
from __future__ import annotations

import argparse
import json
import shutil
from datetime import datetime, timezone
from pathlib import Path

import lightgbm as lgb
import numpy as np
from sklearn.model_selection import train_test_split

from . import data

COVERAGE_TARGET = 0.80
PARAMS = dict(
    objective="regression_l1", learning_rate=0.08, num_leaves=63, min_data_in_leaf=10,
    feature_fraction=0.9, bagging_fraction=0.9, bagging_freq=1, cat_smooth=10, verbose=-1, seed=7,
)


def mape(y, p, w=None):
    return float(np.average(np.abs(p - y) / y, weights=w))


def train(df, seed=7):
    train_df, rest = train_test_split(df, test_size=0.3, random_state=seed)
    calib_df, test_df = train_test_split(rest, test_size=0.5, random_state=seed)

    cats = {"make": sorted(df.make.unique()), "make_model": sorted((df.make + "|" + df.model).unique())}

    def xy(d):
        return data.features(d.make, d.model, d.year, d.mileage, cats), np.log(d.price.to_numpy()), np.sqrt(d.listings.to_numpy())

    xtr, ytr, wtr = xy(train_df)
    xca, yca, _ = xy(calib_df)
    xte, yte, wte = xy(test_df)

    booster = lgb.train(
        PARAMS, lgb.Dataset(xtr, ytr, weight=wtr), num_boost_round=6000,
        valid_sets=[lgb.Dataset(xca, yca)], callbacks=[lgb.early_stopping(100, verbose=False)],
    )

    resid = np.abs(yca - booster.predict(xca))
    n = len(resid)
    q = float(np.quantile(resid, min(1.0, np.ceil((n + 1) * COVERAGE_TARGET) / n)))

    pred = booster.predict(xte)
    price, est = np.exp(yte), np.exp(pred)
    covered = (yte >= pred - q) & (yte <= pred + q)

    base = train_df.groupby(["make", "model"]).price.median()
    base_pred = test_df.set_index(["make", "model"]).index.map(base).to_numpy(dtype=float)
    base_pred = np.where(np.isnan(base_pred), train_df.price.median(), base_pred)

    metrics = {
        "test_rows": int(len(test_df)),
        "mae_usd": float(np.average(np.abs(est - price), weights=wte)),
        "mape": mape(price, est, wte),
        "baseline_mape": mape(price, base_pred, wte),
        "interval_coverage": float(covered.mean()),
        "interval_log_halfwidth": q,
        "best_iteration": int(booster.best_iteration),
    }
    return booster, cats, metrics


def current_metrics(models: Path):
    card = models / "current" / "card.json"
    return json.loads(card.read_text())["metrics"] if card.exists() else None


def accept(new, old):
    calibrated = abs(new["interval_coverage"] - COVERAGE_TARGET) <= 0.05
    better = old is None or new["mape"] <= old["mape"] * 1.02
    return calibrated and better


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--models", type=Path, required=True)
    ap.add_argument("--data", type=Path)
    ap.add_argument("--force", action="store_true")
    args = ap.parse_args()

    src = args.data or data.download(args.models / "incoming" / "prices.csv")
    df = data.load(src)
    booster, cats, metrics = train(df)

    version = f"{datetime.now(timezone.utc):%Y%m%d-%H%M}-{data.fingerprint(src)}"
    out = args.models / "versions" / version
    out.mkdir(parents=True, exist_ok=True)
    booster.save_model(out / "price.txt", num_iteration=booster.best_iteration)
    card = {
        "version": version,
        "trained_at": datetime.now(timezone.utc).isoformat(timespec="seconds"),
        "rows": int(len(df)),
        "data": {"source": data.SOURCE_URL, "sha256_12": data.fingerprint(src), "attribution": data.ATTRIBUTION},
        "target": "log average asking price per make, model and model year (USD)",
        "interval": f"split-conformal, {int(COVERAGE_TARGET * 100)}% nominal",
        "metrics": metrics,
        "categories": cats,
    }
    (out / "card.json").write_text(json.dumps(card, indent=2))

    old = current_metrics(args.models)
    promoted = args.force or accept(metrics, old)
    if promoted:
        tmp = args.models / "current.tmp"
        shutil.rmtree(tmp, ignore_errors=True)
        shutil.copytree(out, tmp)
        shutil.rmtree(args.models / "current", ignore_errors=True)
        tmp.rename(args.models / "current")
    print(json.dumps({"version": version, "promoted": promoted, "metrics": metrics, "previous": old}, indent=2))


if __name__ == "__main__":
    main()
