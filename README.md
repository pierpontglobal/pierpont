# Pierpont

Live used-car auctions with machine-learned price guidance. A rebuild of the Pierpont Global
auction platform (2018–2019) as a compact, self-hosted demo: **https://ppg.hect.dev**

| Part | Stack | Path |
|---|---|---|
| Marketplace | Rails 8.1, Ruby 4.0, Hotwire, Postgres 18, Solid Queue/Cable/Cache | `web/` |
| ML service | FastAPI, LightGBM, ONNX Runtime, Prometheus | `ml/` |
| Deploy | Helm chart for k3s: StatefulSet, CronJob, NetworkPolicies | `deploy/helm/pierpont` |

## What it does

- **Live bidding.** Bids stream to every open page over Turbo Streams. Bids in the last two minutes
  extend the auction. Reserve prices, minimum increments and row-locked bid placement.
- **Price estimates.** LightGBM on log price per make, model and model year, with mileage features.
  80% split-conformal intervals calibrated on held-out data. On the current data: 15.4% MAPE against
  46% for a per-model median baseline, 81% interval coverage.
- **Photo-assisted listings.** CLIP ViT-B/32's image tower is exported to ONNX and quantized to int8
  (84 MB, 28 ms per photo on two cores, 2.4× faster than fp32 with the same body-style accuracy).
  Zero-shot prompts reject non-vehicle photos and suggest body style and color.
- **VIN decoding** through NHTSA vPIC.
- **Retraining.** A weekly CronJob retrains on fresh data and promotes the model only if error stays
  within 2% of the current one and interval coverage within 5 points of target. The API hot-reloads
  promoted models and exports the loaded version and test error to Prometheus.
- **Simulated market.** Bot dealers value each car around the estimate and bid against visitors, and
  demo auctions relist after they end, so the demo is always live.

The whole stack runs in three pods using about 0.8 GiB of memory; the 2019 version needed seven pods
(Rails, Sidekiq, Redis, Elasticsearch, Kibana, two React apps) and about 1.6 GiB.

## Run locally

```bash
docker compose up --build        # web http://localhost:3000, ML http://localhost:8000
docker compose run --rm web bin/rails db:seed
```

Tests: `cd ml && pytest`, `cd web && bin/rails test`.

## ML

```bash
cd ml
python -m pierpont_ml.train --models ./models --data data/used-car-prices-by-model-year.csv
python -m pierpont_ml.export --out ./models/vision         # needs the [export] extra
python -m pierpont_ml.eval_vision --models ./models/vision --samples samples
```

`GET /v1/models` returns the live model card; `/metrics` is Prometheus.

## Data and credits

- Price data: [ForCar open data](https://forcar.org/open-data/), CC BY 4.0.
- VIN decoding: [NHTSA vPIC](https://vpic.nhtsa.dot.gov/api/), public domain.
- Demo photos: Wikimedia Commons, credited on each listing (`web/db/seeds/vehicles.json`).
- CLIP: [openai/clip-vit-base-patch32](https://huggingface.co/openai/clip-vit-base-patch32), MIT.

Auctions on the demo are simulated. No vehicles are sold.
