"""FastAPI backend cho dự báo nhiệt độ kỳ vọng trong phạm vi 12 tháng."""

from fastapi import FastAPI, HTTPException
from pydantic import BaseModel

from app.prediction import predict_for_city_date


app = FastAPI(title="Climate Temperature Prediction API")


class CityDatePredictionInput(BaseModel):
    """Ba thông tin duy nhất người dùng cần cung cấp."""

    city_label: str
    year: int
    month: int


@app.get("/health")
def health_check() -> dict:
    return {"status": "ok"}


def _predict(input_data: CityDatePredictionInput) -> dict:
    try:
        result = predict_for_city_date(
            city_label=input_data.city_label,
            year=input_data.year,
            month=input_data.month,
        )
        result["predicted_temperature_celsius"] = round(
            result["predicted_temperature_celsius"], 2
        )
        return result
    except FileNotFoundError as error:
        raise HTTPException(status_code=503, detail=str(error)) from error
    except ValueError as error:
        raise HTTPException(status_code=400, detail=str(error)) from error


@app.post("/predict")
def predict(input_data: CityDatePredictionInput) -> dict:
    """Dự đoán bằng thành phố, năm và tháng tương lai."""
    return _predict(input_data)


@app.post("/predict/history", deprecated=True)
def predict_legacy_endpoint(input_data: CityDatePredictionInput) -> dict:
    """Endpoint cũ, giữ lại tạm thời để các client cũ không bị hỏng ngay."""
    return _predict(input_data)
