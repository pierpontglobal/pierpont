"""Compare the fp32 and int8 image towers on labeled photos.

python -m pierpont_ml.eval_vision --models /models/vision --samples samples
"""
from __future__ import annotations

import argparse
import json
import time
from pathlib import Path

import numpy as np
from PIL import Image

from .vision import VehicleClassifier


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--models", type=Path, required=True)
    ap.add_argument("--samples", type=Path, required=True)
    args = ap.parse_args()

    items = json.loads((args.samples / "sources.json").read_text())
    images = [Image.open(args.samples / s["file"]) for s in items]
    report = {}
    embs = {}
    for variant in ("fp32", "int8"):
        clf = VehicleClassifier(args.models, variant)
        clf.classify(images[0])
        t = time.perf_counter()
        out = [clf.classify(im) for im in images]
        ms = (time.perf_counter() - t) * 1000 / len(images)
        embs[variant] = np.stack([clf.embed(im) for im in images])
        report[variant] = {
            "latency_ms": round(ms, 1),
            "vehicle_gate": sum(o["is_vehicle"] for o in out) / len(out),
            "body_top1": sum(o["body_style"][0]["label"] == s["body_style"] for o, s in zip(out, items)) / len(items),
            "body_top3": sum(s["body_style"] in [r["label"] for r in o["body_style"]] for o, s in zip(out, items)) / len(items),
            "misses": [(s["file"], s["body_style"], o["body_style"][0]["label"]) for o, s in zip(out, items) if o["body_style"][0]["label"] != s["body_style"]],
        }
    report["embedding_cosine_fp32_vs_int8"] = round(float((embs["fp32"] * embs["int8"]).sum(1).mean()), 4)
    report["samples"] = len(items)
    print(json.dumps(report, indent=1))


if __name__ == "__main__":
    main()
