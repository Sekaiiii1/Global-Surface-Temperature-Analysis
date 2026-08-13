"""
streamlit_app.py — Dashboard, gọi qua REST API (FastAPI) thay vì import trực tiếp.
Chạy: streamlit run app/streamlit_app.py
Yêu cầu: FastAPI phải đang chạy trước ở terminal khác (uvicorn app.api:app --reload)
"""
import streamlit as st
import requests

API_URL = "http://127.0.0.1:8000/predict"
HEALTH_URL = "http://127.0.0.1:8000/health"

st.set_page_config(page_title="Dự báo nhiệt độ bề mặt Trái Đất", page_icon="🌍", layout="centered")

# --- Kiểm tra API có đang chạy không, báo ngay từ đầu thay vì đợi user bấm nút ---
try:
    requests.get(HEALTH_URL, timeout=2)
    api_online = True
except requests.exceptions.ConnectionError:
    api_online = False

st.title("🌍 Dự báo nhiệt độ thành phố")
st.markdown("Nhập thông tin để nhận nhiệt độ trung bình dự kiến (°C).")

if not api_online:
    st.warning(
        "⚠️ Chưa kết nối được FastAPI. Hãy mở terminal khác và chạy:\n\n"
        "`uvicorn app.api:app --reload`",
        icon="⚠️",
    )

with st.form("prediction_form"):
    col1, col2 = st.columns(2)
    with col1:
        year = st.number_input("Năm", min_value=1900, max_value=2050, value=2025)
        latitude = st.number_input("Vĩ độ (Latitude)", value=10.80, format="%.2f")
        temp_lag_1 = st.number_input("Nhiệt độ tháng trước (°C)", value=25.0)
    with col2:
        month = st.selectbox("Tháng", list(range(1, 13)))
        longitude = st.number_input("Kinh độ (Longitude)", value=106.60, format="%.2f")
        temp_roll_mean_12 = st.number_input("Nhiệt độ TB 12 tháng gần nhất (°C)", value=25.0)

    temp_anomaly_lag_12 = st.number_input(
        "Chênh lệch so với cùng kỳ năm trước (°C)", value=0.0,
        help="Nhiệt độ tháng này trừ nhiệt độ cùng tháng năm ngoái"
    )

    submitted = st.form_submit_button("🔮 Dự đoán", use_container_width=True)

if submitted:
    input_dict = {
        "year": year,
        "month": month,
        "quarter": (month - 1) // 3 + 1,
        "latitude": latitude,
        "longitude": longitude,
        "temp_lag_1": temp_lag_1,
        "temp_roll_mean_12": temp_roll_mean_12,
        "temp_anomaly_lag_12": temp_anomaly_lag_12,
        # ⚠️ điền nốt các feature còn lại khi có đủ danh sách 19 cột
    }

    with st.spinner("Đang gọi API và tính toán dự đoán..."):
        try:
            response = requests.post(API_URL, json=input_dict, timeout=5)
            response.raise_for_status()
            result = response.json()["predicted_temperature_celsius"]

            st.success(f"🌡️ Nhiệt độ dự đoán: **{result:.2f}°C**")
            st.balloons()

        except requests.exceptions.ConnectionError:
            st.error(
                "❌ Không kết nối được API. Kiểm tra lại FastAPI đã chạy chưa "
                "(`uvicorn app.api:app --reload`)."
            )
        except requests.exceptions.HTTPError as e:
            detail = e.response.json().get("detail", str(e))
            st.error(f"❌ API báo lỗi: {detail}")
        except Exception as e:
            st.error(f"❌ Lỗi không xác định: {e}")