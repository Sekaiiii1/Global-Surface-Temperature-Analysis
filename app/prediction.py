"""Giao diện Streamlit cho dự đoán nhiệt độ trung bình kỳ vọng theo thành phố."""
from datetime import date

import requests
import streamlit as st

from prediction_service import MAX_REFERENCE_YEARS, forecast_window, get_city_list


API_URL = "http://127.0.0.1:8000/predict"
HEALTH_URL = "http://127.0.0.1:8000/health"

st.set_page_config(page_title="Dự đoán nhiệt độ", page_icon="🔮", layout="wide")

st.markdown(
    """
    <style>
        .prediction-hero {
            position: relative; overflow: hidden; padding: 2.2rem 2.35rem;
            border-radius: 20px; margin-bottom: 1.35rem;
            background: linear-gradient(115deg, #19254b 0%, #204b6d 52%, #17645e 100%);
            border: 1px solid rgba(139, 211, 255, .35);
        }
        .prediction-hero:after {
            content: '☀'; position: absolute; right: 4%; top: -43px; opacity: .18;
            font-size: 10rem; transform: rotate(-13deg);
        }
        .prediction-hero h1 { margin: 0; font-size: 2.5rem; position: relative; }
        .prediction-hero p { margin: .55rem 0 0; max-width: 760px; color: #d5e8f4;
                             font-size: 1.06rem; position: relative; }
        .form-shell {
            padding: 1.35rem 1.45rem .7rem; border-radius: 18px;
            background: rgba(24, 35, 58, .66); border: 1px solid rgba(133, 176, 224, .28);
        }
        .form-shell h3 { margin: 0 0 .15rem; }
        .form-shell p { color: #aebfd1; margin: 0 0 1rem; }
        .step-card {
            height: 100%; min-height: 112px; padding: 1rem 1.05rem; border-radius: 14px;
            background: linear-gradient(145deg, rgba(52, 84, 119, .36), rgba(25, 38, 61, .56));
            border: 1px solid rgba(126, 188, 229, .18);
        }
        .step-number { color: #6ad6ff; font-size: .75rem; font-weight: 800; letter-spacing: .08em; }
        .step-card h4 { margin: .28rem 0 .35rem; }
        .step-card p { margin: 0; color: #c3d2df; font-size: .9rem; }
        .result-card {
            padding: 1.55rem 1.7rem; border-radius: 18px;
            background: linear-gradient(125deg, #123657, #175164 55%, #246149);
            border: 1px solid rgba(123, 229, 193, .35); text-align: center;
        }
        .result-label { font-size: .92rem; color: #d1f3ec; letter-spacing: .04em; }
        .result-value { font-size: 3.7rem; line-height: 1.12; font-weight: 800; color: #ffffff; }
        .result-meta { color: #e2f2f4; margin-top: .35rem; }
        .section-kicker { color: #7ccdf3; font-size: .8rem; font-weight: 800;
                           letter-spacing: .1em; text-transform: uppercase; }
        .note-card { padding: 1rem 1.15rem; border-radius: 13px; min-height: 96px;
                     background: rgba(42, 62, 88, .36); border-left: 4px solid #62d2b1; }
        .note-card h4 { margin: 0 0 .3rem; }
        .note-card p { margin: 0; color: #c3d2df; }
    </style>
    <div class="prediction-hero">
        <h1>🔮 Dự đoán nhiệt độ thành phố</h1>
        <p>Chọn thành phố và thời điểm. Hệ thống tự kết hợp đặc điểm mùa vụ, vị trí địa lý và khí hậu nền để ước tính nhiệt độ trung bình kỳ vọng.</p>
    </div>
    """,
    unsafe_allow_html=True,
)


def months_from_current(year: int, month: int) -> int:
    """Trả về số tháng từ tháng hiện tại tới tháng người dùng chọn."""
    now = date.today().replace(day=1)
    return (year - now.year) * 12 + month - now.month


def temperature_description(value: float) -> tuple[str, str]:
    """Đổi nhiệt độ ước tính thành mô tả ngắn để hiển thị trên giao diện."""
    if value < 0:
        return "❄️ Rất lạnh", "Mức nhiệt trung bình dưới 0 °C"
    if value < 12:
        return "🧣 Se lạnh", "Mức nhiệt trung bình thấp"
    if value < 22:
        return "🌤️ Ôn hòa", "Mức nhiệt trung bình dễ chịu"
    if value < 30:
        return "☀️ Ấm áp", "Mức nhiệt trung bình cao"
    return "🔥 Nóng", "Mức nhiệt trung bình rất cao"


try:
    api_online = requests.get(HEALTH_URL, timeout=2).ok
except requests.RequestException:
    api_online = False

try:
    city_options = get_city_list()
    earliest_month, latest_month = forecast_window()
except FileNotFoundError as error:
    st.error(f"❌ {error}")
    st.stop()

if api_online:
    st.caption("🟢 API dự đoán đang sẵn sàng. Chọn thông tin bên dưới để bắt đầu.")
else:
    st.warning(
        "⚠️ Chưa kết nối FastAPI. Hãy chạy `uvicorn app.api:app --reload` trong một terminal khác, "
        "sau đó tải lại trang này."
    )

form_column, guide_column = st.columns([1.35, 1], gap="large")
with form_column:
    with st.container(border=True):
        st.subheader("📍 Chọn thời điểm và địa điểm")
        st.caption("Không cần nhập nhiệt độ lịch sử hoặc tọa độ.")
        with st.form("prediction_form"):
            city_label = st.selectbox(
                "Thành phố",
                options=city_options,
                help="Tên thành phố được ghép với quốc gia để tránh nhầm các thành phố trùng tên.",
            )
            year_col, month_col = st.columns(2)
            with year_col:
                year = st.selectbox(
                    "Năm dự đoán",
                    list(range(earliest_month.year, latest_month.year + 1)),
                )
            with month_col:
                allowed_months = (
                    list(range(earliest_month.month, 13))
                    if year == earliest_month.year
                    else list(range(1, 13))
                )
                month = st.selectbox(
                    "Tháng dự đoán",
                    allowed_months,
                    format_func=lambda value: f"Tháng {value:02d}",
                )
            submitted = st.form_submit_button("✨ Tạo dự đoán", use_container_width=True)

with guide_column:
    st.markdown('<div class="section-kicker">Cách hệ thống hoạt động</div>', unsafe_allow_html=True)
    guide_1, guide_2, guide_3 = st.columns(3, gap="small")
    with guide_1:
        st.markdown('<div class="step-card"><div class="step-number">BƯỚC 01</div><h4>Chọn nơi chốn</h4><p>Thành phố xác định khí hậu nền, quốc gia và tọa độ đã có sẵn.</p></div>', unsafe_allow_html=True)
    with guide_2:
        st.markdown('<div class="step-card"><div class="step-number">BƯỚC 02</div><h4>Chọn thời điểm</h4><p>Tháng và năm tạo các feature mùa vụ, chu kỳ và xu hướng thời gian.</p></div>', unsafe_allow_html=True)
    with guide_3:
        st.markdown('<div class="step-card"><div class="step-number">BƯỚC 03</div><h4>Nhận ước tính</h4><p>Linear Regression tổng hợp các feature để trả về nhiệt độ kỳ vọng.</p></div>', unsafe_allow_html=True)

    selected_horizon = months_from_current(year, month)
    if selected_horizon <= 12:
        st.success(f"✓ Thời điểm đã chọn cách hiện tại khoảng {selected_horizon} tháng — nằm trong horizon 12 tháng đã backtest.")
    else:
        st.info(f"⌛ Thời điểm đã chọn cách hiện tại khoảng {selected_horizon} tháng — đây là kịch bản tham khảo dài hạn.")

if submitted:
    with st.spinner("Đang tạo feature và tính nhiệt độ kỳ vọng..."):
        try:
            response = requests.post(
                API_URL,
                json={"city_label": city_label, "year": year, "month": month},
                timeout=30,
            )
            response.raise_for_status()
            prediction = response.json()
        except requests.RequestException as error:
            detail = "Không thể gọi API dự đoán."
            if getattr(error, "response", None) is not None:
                try:
                    detail = error.response.json().get("detail", detail)
                except ValueError:
                    detail = str(error)
            st.error(f"❌ {detail}")
            st.stop()

    result = float(prediction["predicted_temperature_celsius"])
    status_title, status_description = temperature_description(result)
    is_reference = bool(prediction["is_long_term_reference"])

    st.markdown("---")
    st.markdown('<div class="section-kicker">Kết quả dự đoán</div>', unsafe_allow_html=True)
    result_col, detail_col = st.columns([1.05, 1], gap="large")
    with result_col:
        st.markdown(
            f'''<div class="result-card">
                <div class="result-label">NHIỆT ĐỘ TRUNG BÌNH KỲ VỌNG</div>
                <div class="result-value">{result:.2f} °C</div>
                <div class="result-meta">{city_label} · Tháng {month:02d}/{year}</div>
            </div>''',
            unsafe_allow_html=True,
        )
    with detail_col:
        forecast_label = "Đã backtest trong phạm vi 12 tháng" if not is_reference else "Kịch bản tham khảo ngoài horizon 12 tháng"
        st.metric("Phân loại nhiệt cảm nhận", status_title, status_description)
        st.metric("Độ xa dự đoán", f"{max(months_from_current(year, month), 0)} tháng", forecast_label)

    note_left, note_right = st.columns(2, gap="large")
    with note_left:
        st.markdown(
            "<div class='note-card'><h4>🧠 Dự đoán dựa trên gì?</h4><p>Model dùng 15 feature đã biết tại thời điểm dự đoán: mùa vụ, vị trí địa lý, xu hướng theo năm, khí hậu trung bình của thành phố và quốc gia.</p></div>",
            unsafe_allow_html=True,
        )
    with note_right:
        if is_reference:
            st.markdown(
                "<div class='note-card'><h4>⚠️ Lưu ý về độ tin cậy</h4><p>Mô hình chỉ được đánh giá bằng backtest đến 12 tháng. Kết quả xa hơn là ngoại suy tham khảo, không phải dự báo thời tiết chính xác.</p></div>",
                unsafe_allow_html=True,
            )
        else:
            st.markdown(
                "<div class='note-card'><h4>✓ Phạm vi đã đánh giá</h4><p>Thời điểm này thuộc horizon 12 tháng đã được backtest. Giá trị là nhiệt độ trung bình kỳ vọng theo tháng, không phải nhiệt độ từng ngày.</p></div>",
                unsafe_allow_html=True,
            )

st.caption(
    f"Phạm vi chọn: {earliest_month:%m/%Y} đến 12/{latest_month.year} (tối đa {MAX_REFERENCE_YEARS} năm). "
    "Các dự đoán ngoài 12 tháng chỉ phục vụ tham khảo xu hướng khí hậu."
)
