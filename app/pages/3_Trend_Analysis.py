"""Trang Phân tích xu hướng — nhiệt độ theo năm."""
import streamlit as st
import pandas as pd
import plotly.express as px
from pathlib import Path

st.set_page_config(page_title="Phân tích xu hướng", page_icon="📈", layout="wide")
st.title("📈 Xu hướng nhiệt độ theo thời gian")

SAMPLE_PATH = Path(__file__).resolve().parent.parent.parent / "data" / "sample" / "feature_sample.csv"

@st.cache_data
def load_data():
    df = pd.read_csv(SAMPLE_PATH)
    if "year" not in df.columns and "observation_date" in df.columns:
        df["year"] = pd.to_datetime(df["observation_date"]).dt.year
    return df

df = load_data()
target_col = "city_average_temperature"

if target_col not in df.columns or "year" not in df.columns:
    st.error("Thiếu cột 'year' hoặc cột nhiệt độ mục tiêu trong dữ liệu.")
    st.stop()

year_min, year_max = int(df["year"].min()), int(df["year"].max())
year_range = st.slider(
    "Chọn khoảng năm", min_value=year_min, max_value=year_max,
    value=(year_min, year_max),
)

filtered = df[(df["year"] >= year_range[0]) & (df["year"] <= year_range[1])]
yearly_avg = filtered.groupby("year")[target_col].mean().reset_index()

fig = px.line(
    yearly_avg, x="year", y=target_col, markers=True,
    labels={"year": "Năm", target_col: "Nhiệt độ trung bình (°C)"},
    title=f"Xu hướng nhiệt độ trung bình {year_range[0]} – {year_range[1]}",
)
fig.update_traces(line_color="#4CAF50")
st.plotly_chart(fig, use_container_width=True)

if len(yearly_avg) > 1:
    change = yearly_avg[target_col].iloc[-1] - yearly_avg[target_col].iloc[0]
    st.metric(
        f"Thay đổi {year_range[0]} → {year_range[1]}",
        f"{change:+.2f} °C",
        delta=f"{change:+.2f} °C",
    )