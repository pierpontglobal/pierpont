import json
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[1]


@pytest.fixture(scope="session")
def models_dir(tmp_path_factory):
    from pierpont_ml import data, train

    out = tmp_path_factory.mktemp("models")
    df = data.load(ROOT / "data" / "used-car-prices-by-model-year.csv")
    booster, cats, metrics = train.train(df)
    (out / "current").mkdir()
    booster.save_model(out / "current" / "price.txt", num_iteration=booster.best_iteration)
    card = {"version": "test", "trained_at": "", "rows": len(df), "data": {}, "target": "", "interval": "", "metrics": metrics, "categories": cats}
    (out / "current" / "card.json").write_text(json.dumps(card))
    return out
