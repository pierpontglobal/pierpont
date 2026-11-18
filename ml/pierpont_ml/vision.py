from __future__ import annotations

import io
import json
from pathlib import Path

import numpy as np
import onnxruntime as ort
from PIL import Image, ImageOps


class VehicleClassifier:
    def __init__(self, root: Path, variant: str = "int8", threads: int = 2):
        self.meta = json.loads((root / "vision.json").read_text())
        labels = np.load(root / "labels.npz")
        self.text = {k: labels[k] for k in labels.files}
        opts = ort.SessionOptions()
        opts.intra_op_num_threads = threads
        opts.graph_optimization_level = ort.GraphOptimizationLevel.ORT_ENABLE_ALL
        self.session = ort.InferenceSession(str(root / f"clip_image_{variant}.onnx"), opts, providers=["CPUExecutionProvider"])
        self.mean = np.array(self.meta["image_mean"], dtype=np.float32)[:, None, None]
        self.std = np.array(self.meta["image_std"], dtype=np.float32)[:, None, None]
        self.variant = variant

    def preprocess(self, img: Image.Image) -> np.ndarray:
        size = self.meta["size"]
        img = ImageOps.exif_transpose(img).convert("RGB")
        w, h = img.size
        s = size / min(w, h)
        img = img.resize((max(size, round(w * s)), max(size, round(h * s))), Image.BICUBIC)
        w, h = img.size
        left, top = (w - size) // 2, (h - size) // 2
        img = img.crop((left, top, left + size, top + size))
        x = np.asarray(img, dtype=np.float32).transpose(2, 0, 1) / 255.0
        return ((x - self.mean) / self.std)[None]

    def embed(self, img: Image.Image) -> np.ndarray:
        return self.session.run(None, {"pixel_values": self.preprocess(img)})[0][0]

    def _rank(self, emb, group, k=3):
        logits = self.meta["logit_scale"] * (self.text[group] @ emb)
        p = np.exp(logits - logits.max())
        p /= p.sum()
        idx = np.argsort(-p)[:k]
        return [{"label": self.meta["labels"][group][i], "p": round(float(p[i]), 4)} for i in idx]

    def classify(self, data: bytes | Image.Image) -> dict:
        img = data if isinstance(data, Image.Image) else Image.open(io.BytesIO(data))
        emb = self.embed(img)
        gate = np.concatenate([self.text["vehicle"], self.text["not_vehicle"]]) @ emb * self.meta["logit_scale"]
        g = np.exp(gate - gate.max())
        p_vehicle = float(g[: len(self.text["vehicle"])].sum() / g.sum())
        return {
            "is_vehicle": p_vehicle >= 0.5,
            "p_vehicle": round(p_vehicle, 4),
            "body_style": self._rank(emb, "body_style"),
            "color": self._rank(emb, "color"),
            "model": f"{self.meta['model']} ({self.variant})",
        }
