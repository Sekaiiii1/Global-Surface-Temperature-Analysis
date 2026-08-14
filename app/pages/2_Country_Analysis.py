"""Trang Phân tích quốc gia."""
import streamlit as st
import pandas as pd
from pathlib import Path

st.set_page_config(page_title="Phân tích quốc gia", page_icon="🌐", layout="wide")
st.title("🌐 Phân tích nhiệt độ theo quốc gia")

SAMPLE_PATH = Path(__file__).resolve().parent.parent.parent / "data" / "sample" / "feature_sample.csv"

@st.cache_data
def load_data():
    df = pd.read_csv(SAMPLE_PATH)
    # Tự suy ra 'year' nếu chưa có sẵn cột này
    if "year" not in df.columns and "observation_date" in df.columns:
        df["year"] = pd.to_datetime(df["observation_date"]).dt.year
    return df

df = load_data()

if "country_name" not in df.columns:
    st.error("File dữ liệu không có cột 'country_name'. Kiểm tra lại feature_sample.csv.")
    st.stop()

target_col = "city_average_temperature" if "city_average_temperature" in df.columns else None
if target_col is None:
    st.error("Không tìm thấy cột nhiệt độ mục tiêu trong file dữ liệu.")
    st.stop()

country_avg = (
    df.groupby("country_name")[target_col]
    .mean()
    .sort_values(ascending=False)
    .reset_index()
    .rename(columns={target_col: "Nhiệt độ TB (°C)", "country_name": "Quốc gia"})
)

col1, col2 = st.columns(2)
with col1:
    st.subheader("🔥 Top 10 quốc gia nóng nhất")
    st.dataframe(country_avg.head(10), use_container_width=True, hide_index=True)
with col2:
    st.subheader("❄️ Top 10 quốc gia lạnh nhất")
    st.dataframe(country_avg.tail(10).sort_values("Nhiệt độ TB (°C)"), use_container_width=True, hide_index=True)

st.markdown("---")
st.subheader("So sánh chi tiết")
selected_countries = st.multiselect(
    "Chọn quốc gia để so sánh",
    options=country_avg["Quốc gia"].tolist(),
    default=country_avg["Quốc gia"].head(5).tolist(),
)
if selected_countries:
    chart_data = country_avg[country_avg["Quốc gia"].isin(selected_countries)]
    st.bar_chart(chart_data.set_index("Quốc gia"))