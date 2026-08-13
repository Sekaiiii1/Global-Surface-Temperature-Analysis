"""
prediction.py — Logic dùng chung cho FastAPI và Streamlit.
Không được duplicate logic này ở 2 nơi (đúng yêu cầu AGENTS.md).
"""
import joblib
import pandas as pd
from pathlib import Path

MODELS_DIR = Path(__file__).resolve().parent.parent / "models"
MODEL_PATH = MODELS_DIR / "model.pkl"
SCALER_PATH = MODELS_DIR / "scaler.pkl"   # bỏ nếu Linear Regression không dùng scaler

# ⚠️ THAY danh sách này bằng đúng thứ tự feature lấy từ feature_metadata.json (NB05)
FEATURE_ORDER = [
    "year", "month", "quarter", "latitude", "longitude",
    "temp_lag_1", "temp_roll_mean_12", "temp_anomaly_lag_12",
    # ... điền đủ 19 cột đúng thứ tự
]

_model = None
_scaler = None


def load_model():
    """Load model 1 lần duy nhất, dùng lại cho các lần gọi sau (tránh load lại mỗi request)."""
    global _model
    if _model is None:
        if not MODEL_PATH.exists():
            raise FileNotFoundError(
                f"Không tìm thấy model tại {MODEL_PATH}. "
                "Hãy chạy Notebook 06 để tạo model.pkl trước."
            )
        _model = joblib.load(MODEL_PATH)
    return _model


def load_scaler():
    """Load scaler nếu có dùng. Nếu Linear Regression không cần scaler, hàm này trả None."""
    global _scaler
    if _scaler is None and SCALER_PATH.exists():
        _scaler = joblib.load(SCALER_PATH)
    return _scaler


def validate_input(input_dict: dict) -> None:
    """Kiểm tra input có đủ field cần thiết trước khi predict."""
    missing = [f for f in FEATURE_ORDER if f not in input_dict]
    if missing:
        raise ValueError(f"Thiếu các trường bắt buộc: {missing}")


def predict_temperature(input_dict: dict) -> float:
    """
    input_dict: dict chứa đúng các feature cần thiết, ví dụ:
        {"year": 2025, "month": 6, "latitude": 10.8, ...}
    Trả về: nhiệt độ dự đoán (float, đơn vị °C)
    """
    validate_input(input_dict)

    model = load_model()
    scaler = load_scaler()

    # Đảm bảo đúng thứ tự cột — bắt buộc, vì model học theo đúng thứ tự lúc train
    X = pd.DataFrame([input_dict])[FEATURE_ORDER]

    if scaler is not None:
        X = scaler.transform(X)

    prediction = model.predict(X)
    return float(prediction[0])