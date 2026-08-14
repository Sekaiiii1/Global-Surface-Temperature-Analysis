"""Logic tạo feature và dự đoán dùng chung cho Streamlit/FastAPI."""
from __future__ import annotations

import json
from datetime import date
from functools import lru_cache
from pathlib import Path

import joblib
import numpy as np
import pandas as pd

BASE_DIR = Path(__file__).resolve().parent.parent
MODEL_PATH = BASE_DIR / "models" / "model.pkl"
MODEL_METADATA_PATH = BASE_DIR / "models" / "model_metadata.json"
FEATURE_METADATA_PATH = BASE_DIR / "data" / "processed" / "feature_metadata.json"
STATS_PATH = BASE_DIR / "data" / "processed" / "feature_statistics.csv.gz"
DATA_START_YEAR = 1863
MAX_REFERENCE_YEARS = 100


@lru_cache(maxsize=1)
def load_model_metadata() -> dict:
    with MODEL_METADATA_PATH.open(encoding="utf-8") as file:
        return json.load(file)


@lru_cache(maxsize=1)
def load_feature_metadata() -> dict:
    with FEATURE_METADATA_PATH.open(encoding="utf-8") as file:
        return json.load(file)


def _add_months(value: date, months: int) -> date:
    index = value.year * 12 + value.month - 1 + months
    return date(index // 12, index % 12 + 1, 1)


def forecast_window(today: date | None = None) -> tuple[date, date]:
    today = today or date.today()
    start = today.replace(day=1)
    return start, date(start.year + MAX_REFERENCE_YEARS, 12, 1)


def validate_forecast_date(year: int, month: int) -> date:
    try:
        selected = date(int(year), int(month), 1)
    except (TypeError, ValueError) as error:
        raise ValueError("Năm hoặc tháng không hợp lệ.") from error
    start, end = forecast_window()
    if not start <= selected <= end:
        raise ValueError(f"Chỉ cho phép chọn từ {start:%m/%Y} đến {end:%m/%Y}.")
    return selected


@lru_cache(maxsize=1)
def load_model():
    if not MODEL_PATH.exists():
        raise FileNotFoundError("Không tìm thấy model.pkl; hãy chạy Notebook 06.")
    return joblib.load(MODEL_PATH)


@lru_cache(maxsize=1)
def load_location_stats() -> pd.DataFrame:
    if not STATS_PATH.exists():
        raise FileNotFoundError("Không tìm thấy feature_statistics.csv.gz; hãy chạy Notebook 05.")
    return pd.read_csv(STATS_PATH, compression="gzip")


def get_city_list() -> list[str]:
    rows = load_location_stats()[["city_name", "country_name"]].drop_duplicates()
    return sorted(f"{row.city_name} ({row.country_name})" for row in rows.itertuples())


def _location(city_label: str, month: int) -> pd.Series:
    try:
        city, country = city_label.rsplit(" (", 1)
        country = country.rstrip(")")
    except (AttributeError, ValueError) as error:
        raise ValueError("Thành phố phải có dạng 'Thành phố (Quốc gia)'.") from error
    rows = load_location_stats()
    row = rows.loc[(rows.city_name == city) & (rows.country_name == country) & (rows.month == month)]
    if row.empty:
        raise ValueError(f"Không tìm thấy thống kê cho {city_label}, tháng {month}.")
    return row.iloc[0]


def build_features_for_city_date(city_label: str, year: int, month: int) -> pd.DataFrame:
    target = validate_forecast_date(year, month)
    row = _location(city_label, target.month)
    latitude = float(row.latitude)
    absolute_latitude = abs(latitude)
    climatic_month = target.month if latitude >= 0 else ((target.month + 5) % 12) + 1
    month_angle = 2 * np.pi * target.month / 12
    climatic_angle = 2 * np.pi * climatic_month / 12
    values = {
        "month_sin": np.sin(month_angle), "month_cos": np.cos(month_angle),
        "climatic_month_sin": np.sin(climatic_angle), "climatic_month_cos": np.cos(climatic_angle),
        "years_since_start": target.year - DATA_START_YEAR, "latitude": latitude,
        "abs_latitude": absolute_latitude, "hemisphere_north": int(latitude >= 0),
        "longitude": float(row.longitude),
        "abslat_x_month_sin": absolute_latitude * np.sin(climatic_angle),
        "abslat_x_month_cos": absolute_latitude * np.cos(climatic_angle),
        "loc_month_climatology": float(row.loc_month_climatology),
        "loc_mean_temperature": float(row.loc_mean_temperature),
        "loc_temperature_std": float(row.loc_temperature_std),
        "country_name": str(row.country_name),
    }
    metadata, feature_metadata = load_model_metadata(), load_feature_metadata()
    names = metadata["feature_names"]
    if names != feature_metadata["feature_names"]:
        raise ValueError("Feature contract Notebook 05 và model metadata không khớp.")
    frame = pd.DataFrame([values], columns=names)
    if not np.isfinite(frame[metadata["numeric_feature_names"]].to_numpy(dtype=float)).all():
        raise ValueError("Feature số có giá trị không hợp lệ.")
    return frame


def predict_for_city_date(city_label: str, year: int, month: int) -> dict:
    target = validate_forecast_date(year, month)
    result = float(load_model().predict(build_features_for_city_date(city_label, year, month))[0])
    start = date.today().replace(day=1)
    return {
        "city_label": city_label, "year": target.year, "month": target.month,
        "target_date": target.isoformat(), "predicted_temperature_celsius": result,
        "forecast_type": "expected_climatological_monthly_mean",
        "validated_horizon_months": int(load_model_metadata().get("forecast_horizon_months", 12)),
        "is_long_term_reference": target > _add_months(start, 12),
    }
