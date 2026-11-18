"""Export CLIP's image tower to ONNX (fp32 and int8) and precompute label embeddings.

python -m pierpont_ml.export --out /models/vision
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path

import numpy as np
import torch
from transformers import CLIPModel, CLIPProcessor

MODEL_ID = "openai/clip-vit-base-patch32"

LABELS = {
    "vehicle": ["a car", "a pickup truck", "an SUV", "a van"],
    "not_vehicle": ["a person", "a document", "a building", "an animal", "food", "a screenshot", "a landscape"],
    "body_style": ["sedan", "SUV", "pickup truck", "coupe", "convertible", "hatchback", "minivan", "station wagon", "cargo van"],
    "color": ["black", "white", "silver", "gray", "red", "blue", "green", "beige", "yellow", "orange", "brown"],
    "make": [
        "Toyota", "Honda", "Ford", "Chevrolet", "Nissan", "Hyundai", "Kia", "Subaru", "Mazda", "Volkswagen",
        "BMW", "Mercedes-Benz", "Audi", "Lexus", "Jeep", "Ram", "GMC", "Dodge", "Tesla", "Porsche",
        "Volvo", "Acura", "Infiniti", "Cadillac", "Lincoln", "Buick", "Chrysler", "Land Rover", "Mitsubishi", "Mini",
    ],
}

TEMPLATES = {
    "vehicle": ["a photo of {}.", "a picture of {}."],
    "not_vehicle": ["a photo of {}.", "a picture of {}."],
    "body_style": ["a photo of a {} car.", "a {} parked on the street.", "a used {} for sale."],
    "color": ["a photo of a {} car.", "a {} colored vehicle."],
    "make": ["a photo of a {} car.", "a {} vehicle.", "the front of a {} car."],
}


class ImageTower(torch.nn.Module):
    def __init__(self, clip):
        super().__init__()
        self.clip = clip

    def forward(self, pixel_values):
        out = self.clip.get_image_features(pixel_values=pixel_values)
        emb = out if isinstance(out, torch.Tensor) else out.pooler_output
        return emb / emb.norm(dim=-1, keepdim=True)


@torch.no_grad()
def text_embeddings(clip, proc):
    result = {}
    for group, names in LABELS.items():
        rows = []
        for name in names:
            prompts = [t.format(name) for t in TEMPLATES[group]]
            tok = proc(text=prompts, return_tensors="pt", padding=True)
            out = clip.get_text_features(**tok)
            e = out if isinstance(out, torch.Tensor) else out.pooler_output
            e = e / e.norm(dim=-1, keepdim=True)
            m = e.mean(0)
            rows.append((m / m.norm()).numpy())
        result[group] = np.stack(rows).astype(np.float32)
    return result


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", type=Path, required=True)
    args = ap.parse_args()
    args.out.mkdir(parents=True, exist_ok=True)

    clip = CLIPModel.from_pretrained(MODEL_ID).eval()
    proc = CLIPProcessor.from_pretrained(MODEL_ID)

    fp32 = args.out / "clip_image_fp32.onnx"
    torch.onnx.export(
        ImageTower(clip), torch.randn(1, 3, 224, 224), fp32, input_names=["pixel_values"],
        output_names=["embedding"], dynamic_axes={"pixel_values": {0: "batch"}, "embedding": {0: "batch"}},
        opset_version=18, dynamo=False,
    )

    from onnxruntime.quantization import QuantType, quantize_dynamic
    int8 = args.out / "clip_image_int8.onnx"
    quantize_dynamic(fp32, int8, weight_type=QuantType.QInt8)

    emb = text_embeddings(clip, proc)
    np.savez(args.out / "labels.npz", **emb)
    ip = proc.image_processor
    meta = {
        "model": MODEL_ID,
        "labels": LABELS,
        "logit_scale": float(clip.logit_scale.exp()),
        "image_mean": list(ip.image_mean),
        "image_std": list(ip.image_std),
        "size": 224,
    }
    (args.out / "vision.json").write_text(json.dumps(meta, indent=2))
    print({p.name: round(p.stat().st_size / 2**20, 1) for p in args.out.glob("*.onnx")})


if __name__ == "__main__":
    main()
