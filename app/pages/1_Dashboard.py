"""Dashboard tổng quan, đồng bộ với metadata của Notebook 05 và 06."""

import json
from pathlib import Path

import pandas as pd
import plotly.express as px
import plotly.graph_objects as go
import streamlit as st


PROJECT_ROOT = Path(__file__).resolve().parents[2]
FEATURE_METADATA_PATH = PROJECT_ROOT / "data" / "processed" / "feature_metadata.json"
MODEL_METADATA_PATH = PROJECT_ROOT / "models" / "model_metadata.json"

st.set_page_config(page_title="Bảng điều khiển", page_icon="📊", layout="wide")
st.markdown(
    """
    <style>
      .dashboard-hero {padding: 1.4rem 1.6rem; border-radius: 18px; border: 1px solid #22577a;
        background: linear-gradient(115deg, #102a43, #0e1117 66%, #173f5f); margin-bottom: 1rem;}
      .dashboard-hero h1 {margin: 0; color: #f7fafc; font-size: 2.25rem;}
      .dashboard-hero p {margin: .55rem 0 0; color: #cbd5e0; font-size: 1.05rem;}
      .pipeline-step {padding: .7rem .35rem; text-align: center; border: 1px solid #2d3748;
        border-radius: 10px; background: #151923; color: #e2e8f0; min-height: 74px;}
      .pipeline-step b {display: block; color: #68d391; margin-bottom: .15rem;}
    </style>
    <div class="dashboard-hero">
      <h1>📊 Bảng điều khiển khí hậu</h1>
      <p>Tổng quan dữ liệu, hiệu suất mô hình và quy trình dự đoán nhiệt độ trung bình kỳ vọng theo thành phố.</p>
    </div>
    """,
    unsafe_allow_html=True,
)

try:
    feature_metadata = json.loads(FEATURE_METADATA_PATH.read_text(encoding="utf-8"))
    model_metadata = json.loads(MODEL_METADATA_PATH.read_text(encoding="utf-8"))
except (FileNotFoundError, json.JSONDecodeError) as error:
    st.error(f"Không đọc được metadata mô hình: {error}")
    st.stop()

st.subheader("📦 Dòng chảy dữ liệu")
col1, col2, col3, col4 = st.columns(4)
with col1:
    st.metric("City raw", "8,599,212", help="Toàn bộ bảng GlobalLandTemperaturesByCity.csv ban đầu.")
with col2:
    st.metric("Sau cắt PostgreSQL", "5,637,812", help="50 quốc gia có số bản ghi lớn nhất, giai đoạn 1863–2013.")
with col3:
    st.metric("Sau Feature Engineering", f"{feature_metadata['row_count']:,}")
with col4:
    st.metric("Feature triển khai", len(feature_metadata["feature_names"]))

start_date, end_date = feature_metadata["observation_date_range"]
st.caption(
    f"Phạm vi mô hình: {start_date} → {end_date} · 50 quốc gia · "
    f"{feature_metadata['location_count']:,} location · Target: city_average_temperature"
)

funnel_col, context_col = st.columns([1.15, 1])
with funnel_col:
    funnel = go.Funnel(
        y=["City raw", "Sau cắt PostgreSQL", "Sau Feature Engineering"],
        x=[8_599_212, 5_637_812, feature_metadata["row_count"]],
        textinfo="value+percent initial",
        marker={"color": ["#3b82f6", "#14b8a6", "#84cc16"]},
    )
    figure_funnel = go.Figure(funnel)
    figure_funnel.update_layout(title="Quy mô dữ liệu qua từng bước", height=280, margin=dict(l=10, r=10, t=50, b=10))
    st.plotly_chart(figure_funnel, use_container_width=True)
with context_col:
    st.markdown("#### 🔎 Cách đọc dashboard")
    st.info(
        "Funnel cho thấy dữ liệu được cắt theo phạm vi nghiên cứu trước khi làm sạch. "
        "Số dòng sau Feature Engineering là tập dữ liệu thực tế dùng để chia train, validation và test."
    )
    st.markdown("#### 🧭 Phạm vi dự đoán")
    st.write(
        "Mô hình được backtest ở horizon 1–12 tháng. Giao diện cho phép xem kịch bản xa hơn, "
        "nhưng các mốc vượt 12 tháng chỉ mang tính tham khảo."
    )

st.markdown("---")
st.subheader("🏁 So sánh mô hình trên tập Validation")
validation_results = pd.DataFrame(
    {
        "Mô hình": ["Linear Regression", "XGBoost", "Random Forest", "Climatology baseline"],
        "MAE (°C)": [0.8699, 0.8864, 0.9165, 0.9734],
        "RMSE (°C)": [1.2787, 1.3152, 1.3493, 1.3664],
        "R²": [0.9839, 0.9829, 0.9820, 0.9816],
        "Loại": ["Mô hình được chọn", "Mô hình ML", "Mô hình ML", "Mốc tham chiếu"],
    }
)

chart_col, table_col = st.columns([1.05, 1])
with chart_col:
    rmse_chart = px.bar(
        validation_results.sort_values("RMSE (°C)", ascending=False),
        x="RMSE (°C)", y="Mô hình", orientation="h", color="Loại",
        color_discrete_map={"Mô hình được chọn": "#22c55e", "Mô hình ML": "#38bdf8", "Mốc tham chiếu": "#f59e0b"},
        text="RMSE (°C)", title="RMSE thấp hơn là tốt hơn",
    )
    rmse_chart.update_traces(texttemplate="%{text:.4f}", textposition="outside")
    rmse_chart.update_layout(height=310, margin=dict(l=10, r=25, t=55, b=20), legend_title_text="Chú thích")
    st.plotly_chart(rmse_chart, use_container_width=True)
with table_col:
    st.dataframe(
        validation_results.drop(columns="Loại").set_index("Mô hình").style.format(
            {"MAE (°C)": "{:.4f}", "RMSE (°C)": "{:.4f}", "R²": "{:.4f}"}
        ),
        use_container_width=True,
    )
    st.success("Linear Regression có RMSE validation thấp nhất và cải thiện so với climatology baseline.")

st.markdown("---")
st.subheader("✅ Kết quả cuối cùng trên tập Test")
test_metrics = model_metadata["metrics_test"]
mae_col, rmse_col, r2_col, model_col = st.columns(4)
mae_col.metric("MAE", f"{test_metrics['MAE']:.4f} °C")
rmse_col.metric("RMSE", f"{test_metrics['RMSE']:.4f} °C")
r2_col.metric("R²", f"{test_metrics['R2']:.4f}")
model_col.metric("Mô hình triển khai", model_metadata["model_type"])

st.markdown("#### 🔄 Pipeline dự án")
steps = [
    ("01", "CSV & khảo sát"), ("02", "PostgreSQL"), ("03", "Cleaning"),
    ("04", "EDA"), ("05", "Feature"), ("06", "Machine Learning"), ("App", "FastAPI + Streamlit"),
]
columns = st.columns(len(steps))
for column, (number, label) in zip(columns, steps):
    with column:
        st.markdown(f'<div class="pipeline-step"><b>{number}</b>{label}</div>', unsafe_allow_html=True)

st.info(
    "👉 Pipeline Linear Regression đã bao gồm preprocessing và One-Hot Encoding cho country_name. "
    "Ứng dụng chỉ cần thành phố, tháng và năm để tạo feature dự đoán."
)
