FROM python:3.12-slim AS build
RUN apt-get update -qq && apt-get install -y -qq libgomp1 >/dev/null && rm -rf /var/lib/apt/lists/*
WORKDIR /src
COPY pyproject.toml .
COPY pierpont_ml pierpont_ml
RUN pip install -q --no-cache-dir --extra-index-url https://download.pytorch.org/whl/cpu ".[train,export]"
COPY data data
RUN python -m pierpont_ml.export --out /models/vision \
 && rm /models/vision/clip_image_fp32.onnx \
 && python -m pierpont_ml.train --models /models --data data/used-car-prices-by-model-year.csv \
 && rm -rf /models/versions

FROM python:3.12-slim
RUN apt-get update -qq && apt-get install -y -qq libgomp1 >/dev/null && rm -rf /var/lib/apt/lists/* \
 && useradd -r -u 10001 app
WORKDIR /app
COPY pyproject.toml .
COPY pierpont_ml pierpont_ml
RUN pip install -q --no-cache-dir ".[train]" && rm -rf /root/.cache
COPY --from=build /models /opt/models
RUN mkdir /models && chown app /models
ENV MODELS_DIR=/models VISION_DIR=/opt/models/vision PYTHONUNBUFFERED=1
USER app
EXPOSE 8000
CMD ["uvicorn", "pierpont_ml.app:app", "--host", "0.0.0.0", "--port", "8000", "--workers", "1"]
