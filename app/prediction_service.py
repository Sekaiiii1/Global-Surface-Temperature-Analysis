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
DATA_START_YEAR, MAX_REFERENCE_YEARS = 1863, 100

@lru_cache(maxsize=1)
def load_model_metadata():
    with MODEL_METADATA_PATH.open(encoding="utf-8") as f: return json.load(f)

@lru_cache(maxsize=1)
def load_feature_metadata():
    with FEATURE_METADATA_PATH.open(encoding="utf-8") as f: return json.load(f)

def _add_months(value, months):
    index = value.year * 12 + value.month - 1 + months
    return date(index // 12, index % 12 + 1, 1)

def forecast_window(today=None):
    start = (today or date.today()).replace(day=1)
    return start, date(start.year + MAX_REFERENCE_YEARS, 12, 1)

def validate_forecast_date(year, month):
    try: selected = date(int(year), int(month), 1)
    except (TypeError, ValueError) as exc: raise ValueError("Năm hoặc tháng không hợp lệ.") from exc
    start, end = forecast_window()
    if not start <= selected <= end: raise ValueError(f"Chỉ cho phép chọn từ {start:%m/%Y} đến {end:%m/%Y}.")
    return selected

@lru_cache(maxsize=1)
def load_model():
    if not MODEL_PATH.exists(): raise FileNotFoundError("Không tìm thấy model.pkl; hãy chạy Notebook 06.")
    return joblib.load(MODEL_PATH)

@lru_cache(maxsize=1)
def load_location_stats():
    if not STATS_PATH.exists(): raise FileNotFoundError("Không tìm thấy feature_statistics.csv.gz; hãy chạy Notebook 05.")
    return pd.read_csv(STATS_PATH, compression="gzip")

def get_city_list():
    data = load_location_stats()[["city_name", "country_name"]].drop_duplicates()
    return sorted(f"{row.city_name} ({row.country_name})" for row in data.itertuples())

def _location(city_label, month):
    try: city, country = city_label.rsplit(" (", 1); country = country.rstrip(")")
    except (AttributeError, ValueError) as exc: raise ValueError("Thành phố phải có dạng 'Thành phố (Quốc gia)'.") from exc
    data = load_location_stats()
    found = data.loc[(data.city_name == city) & (data.country_name == country) & (data.month == month)]
    if found.empty: raise ValueError(f"Không tìm thấy thống kê cho {city_label}, tháng {month}.")
    return found.iloc[0]

def build_features_for_city_date(city_label, year, month):
    target, row = validate_forecast_date(year, month), _location(city_label, int(month))
    latitude, absolute_latitude = float(row.latitude), abs(float(row.latitude))
    climatic_month = target.month if latitude >= 0 else ((target.month + 5) % 12) + 1
    angle, climate_angle = 2*np.pi*target.month/12, 2*np.pi*climatic_month/12
    values = {"month_sin":np.sin(angle),"month_cos":np.cos(angle),"climatic_month_sin":np.sin(climate_angle),"climatic_month_cos":np.cos(climate_angle),"years_since_start":target.year-DATA_START_YEAR,"latitude":latitude,"abs_latitude":absolute_latitude,"hemisphere_north":int(latitude>=0),"longitude":float(row.longitude),"abslat_x_month_sin":absolute_latitude*np.sin(climate_angle),"abslat_x_month_cos":absolute_latitude*np.cos(climate_angle),"loc_month_climatology":float(row.loc_month_climatology),"loc_mean_temperature":float(row.loc_mean_temperature),"loc_temperature_std":float(row.loc_temperature_std),"country_name":str(row.country_name)}
    metadata = load_model_metadata()
    if metadata["feature_names"] != load_feature_metadata()["feature_names"]: raise ValueError("Feature contract Notebook 05 và model metadata không khớp.")
    frame = pd.DataFrame([values], columns=metadata["feature_names"])
    if not np.isfinite(frame[metadata["numeric_feature_names"]].to_numpy(dtype=float)).all(): raise ValueError("Feature số có giá trị không hợp lệ.")
    return frame

def predict_for_city_date(city_label, year, month):
    target = validate_forecast_date(year, month)
    value = float(load_model().predict(build_features_for_city_date(city_label, year, month))[0])
    return {"city_label":city_label,"year":target.year,"month":target.month,"target_date":target.isoformat(),"predicted_temperature_celsius":value,"forecast_type":"expected_climatological_monthly_mean","validated_horizon_months":int(load_model_metadata().get("forecast_horizon_months",12)),"is_long_term_reference":target > _add_months(date.today().replace(day=1),12)}
