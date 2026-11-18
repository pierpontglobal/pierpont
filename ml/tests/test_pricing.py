from pierpont_ml import train
from pierpont_ml.pricing import PriceModel


def test_model_beats_baseline_and_is_calibrated(models_dir):
    m = PriceModel(models_dir).card["metrics"]
    assert m["mape"] < 0.5 * m["baseline_mape"]
    assert abs(m["interval_coverage"] - train.COVERAGE_TARGET) <= 0.05


def test_estimate_is_ordered_and_depreciates(models_dir):
    pm = PriceModel(models_dir)
    new = pm.estimate("Toyota", "Camry", 2024, 15_000)
    old = pm.estimate("Toyota", "Camry", 2012, 140_000)
    assert new["low_usd"] < new["estimate_usd"] < new["high_usd"]
    assert new["estimate_usd"] > old["estimate_usd"]
    assert new["known_model"]


def test_unknown_model_still_answers(models_dir):
    r = PriceModel(models_dir).estimate("Toyota", "Not A Real Model", 2020, 50_000)
    assert r["estimate_usd"] > 0 and not r["known_model"]


def test_gate():
    old = {"mape": 0.15}
    assert train.accept({"mape": 0.152, "interval_coverage": 0.81}, old)
    assert not train.accept({"mape": 0.2, "interval_coverage": 0.8}, old)
    assert not train.accept({"mape": 0.1, "interval_coverage": 0.6}, old)
