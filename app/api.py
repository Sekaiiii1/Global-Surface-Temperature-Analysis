"""
api.py — FastAPI backend.
Chạy bằng: uvicorn app.api:app --reload
"""
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from app.prediction import predict_temperature

app = FastAPI(title="Climate Temperature Prediction API")


class PredictionInput(BaseModel):
    year: int
    month: int
    quarter: int
    latitude: float
    longitude: float
    temp_lag_1: float
    temp_roll_mean_12: float
    temp_anomaly_lag_12: float
    # ⚠️ điền đủ các field còn lại khớp với FEATURE_ORDER


@app.get("/health")
def health_check():
    return {"status": "ok"}


@app.post("/predict")
def predict(input_data: PredictionInput):
    try:
        result = predict_temperature(input_data.dict())
        return {"predicted_temperature_celsius": round(result, 2)}
    except FileNotFoundError as e:
        raise HTTPException(status_code=503, detail=str(e))
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))