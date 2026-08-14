"""Trang Streamlit dự đoán nhiệt độ và kịch bản tham khảo dài hạn."""

import requests
import streamlit as st

from prediction import MAX_REFERENCE_YEARS, forecast_window, get_city_list


API_URL = "http://127.0.0.1:8000/predict"
HEALTH_URL = "http://127.0.0.1:8000/health"

st.set_page_config(page_title="Prediction", page_icon="🔮", layout="centered")
st.title("🔮 Dự đoán nhiệt độ thành phố")
st.markdown("Chọn thành phố, tháng và năm. Kết quả xa hơn 12 tháng được xem là kịch bản tham khảo.")

try:
    api_online = requests.get(HEALTH_URL, timeout=2).ok
except requests.RequestException:
    api_online = False
if not api_online:
    st.warning("⚠️ Chưa kết nối FastAPI. Hãy chạy `uvicorn app.api:app --reload` trong terminal khác.")

try:
    city_options = get_city_list()
    earliest_month, latest_month = forecast_window()
except FileNotFoundError as error:
    st.error(f"❌ {error}")
    st.stop()

with st.form("prediction_form"):
    st.subheader("📍 Thời gian và vị trí")
    city_label = st.selectbox("Chọn thành phố", options=city_options)
    year_col, month_col = st.columns(2)
    with year_col:
        year = st.selectbox("Năm dự đoán", list(range(earliest_month.year, latest_month.year + 1)))
    with month_col:
        months = list(range(earliest_month.month, 13)) if year == earliest_month.year else list(range(1, 13))
        month = st.selectbox("Tháng dự đoán", months, format_func=lambda value: f"Tháng {value:02d}")
    submitted = st.form_submit_button("🔮 Dự đoán", use_container_width=True)

if submitted:
    with st.spinner("Đang gọi API và tính toán dự đoán..."):
        try:
            response = requests.post(API_URL, json={"city_label": city_label, "year": year, "month": month}, timeout=30)
            response.raise_for_status()
            prediction = response.json()
            result = prediction["predicted_temperature_celsius"]
            st.success(f"🌡️ Nhiệt độ trung bình kỳ vọng tại **{city_label}** trong tháng **{month:02d}/{year}**: **{result:.2f}°C**")
            if prediction["is_long_term_reference"]:
                st.warning("Kịch bản tham khảo dài hạn: mô hình chỉ được backtest đến horizon 12 tháng; kết quả xa hơn là ngoại suy chưa được xác minh.")
            else:
                st.info("Thời điểm này nằm trong horizon 12 tháng đã được backtest trên dữ liệu lịch sử.")
        except requests.RequestException as error:
            detail = "Không thể gọi API."
            if getattr(error, "response", None) is not None:
                try:
                    detail = error.response.json().get("detail", detail)
                except ValueError:
                    detail = str(error)
            st.error(f"❌ {detail}")

st.caption(f"Chọn được từ {earliest_month:%m/%Y} đến 12/{latest_month.year}, tối đa {MAX_REFERENCE_YEARS} năm. Không cần nhập nhiệt độ lịch sử hoặc tọa độ.")
