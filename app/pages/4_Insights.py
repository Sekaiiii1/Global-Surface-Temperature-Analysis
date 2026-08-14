"""Trang Thông tin chi tiết — bản đồ + top thành phố."""
import streamlit as st
import pandas as pd
import plotly.express as px
from pathlib import Path

st.set_page_config(page_title="Thông tin chi tiết", page_icon="🗺️", layout="wide")
st.title("🗺️ Bản đồ nhiệt độ & thành phố nổi bật")

STATS_PATH = Path(__file__).resolve().parent.parent.parent / "data" / "processed" / "feature_statistics.csv.gz"

@st.cache_data
def load_data():
    return pd.read_csv(STATS_PATH, compression="gzip")

df = load_data()

month = st.select_slider("Chọn tháng", options=list(range(1, 13)), value=7)
month_df = df[df["month"] == month].drop_duplicates("location_id")

fig = px.scatter_geo(
    month_df, lat="latitude", lon="longitude",
    color="loc_month_climatology", hover_name="city_name",
    hover_data={"country_name": True, "loc_month_climatology": ":.1f"},
    color_continuous_scale="RdYlBu_r", projection="natural earth",
    title=f"Nhiệt độ trung bình lịch sử — Tháng {month}",
)
fig.update_layout(height=600, margin=dict(l=0, r=0, t=40, b=0))
st.plotly_chart(fig, use_container_width=True)

st.markdown("---")
col1, col2 = st.columns(2)
with col1:
    st.subheader("🔥 Top 10 thành phố nóng nhất")
    hot = month_df.nlargest(10, "loc_month_climatology")[["city_name", "country_name", "loc_month_climatology"]]
    hot.columns = ["Thành phố", "Quốc gia", "Nhiệt độ (°C)"]
    st.dataframe(hot, use_container_width=True, hide_index=True)
with col2:
    st.subheader("❄️ Top 10 thành phố lạnh nhất")
    cold = month_df.nsmallest(10, "loc_month_climatology")[["city_name", "country_name", "loc_month_climatology"]]
    cold.columns = ["Thành phố", "Quốc gia", "Nhiệt độ (°C)"]
    st.dataframe(cold, use_container_width=True, hide_index=True)