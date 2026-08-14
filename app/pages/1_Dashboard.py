"""Trang Bảng điều khiển — tổng quan project."""
import streamlit as st
import pandas as pd

st.set_page_config(page_title="Bảng điều khiển", page_icon="📊", layout="wide")
st.title("📊 Bảng điều khiển — Dự đoán nhiệt độ bề mặt Trái Đất")

st.markdown("### Tổng quan Dataset")
col1, col2, col3, col4 = st.columns(4)
col1.metric("Tổng bản ghi (raw)", "5.010.113")
col2.metric("Sau Feature Engineering", "5.579.085")
col3.metric("Khoảng thời gian", "1863 – 2013")
col4.metric("Số đặc trưng", "19")

st.markdown("---")
st.markdown("### So sánh mô hình (trên tập Validation)")

results = pd.DataFrame({
    "Model": ["Linear Regression ⭐", "XGBoost", "Random Forest"],
    "MAE (°C)": [0.8521, 0.8536, 0.8675],
    "RMSE (°C)": [1.2521, 1.2597, 1.2744],
    "R²": [0.9845, 0.9843, 0.9840],
    "Thời gian train (giây)": [1.24, 22.37, 553.03],
}).set_index("Model")

st.dataframe(results, use_container_width=True)
st.caption(
    "Linear Regression được chọn triển khai: độ chính xác gần tương đương "
    "2 mô hình còn lại, nhưng nhanh hơn Random Forest hơn 400 lần và "
    "ổn định nhất giữa Train/Validation (ít dấu hiệu overfit nhất)."
)

st.markdown("---")
st.markdown("### Kết quả trên tập Test (đánh giá cuối cùng)")
col1, col2, col3 = st.columns(3)
col1.metric("MAE", "0.8736 °C")
col2.metric("RMSE", "1.2725 °C")
col3.metric("R²", "0.9839")

st.info("👉 Dùng menu bên trái để xem Phân tích quốc gia, Xu hướng khí hậu, Bản đồ nhiệt độ hoặc chạy Dự đoán.")