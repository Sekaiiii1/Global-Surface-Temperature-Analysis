"""Trang phân tích nhiệt độ trung bình theo quốc gia."""

from pathlib import Path

import pandas as pd
import plotly.express as px
import streamlit as st


st.set_page_config(page_title="Phân tích quốc gia", page_icon="🌐", layout="wide")
st.title("🌐 Phân tích nhiệt độ theo quốc gia")

SAMPLE_PATH = Path(__file__).resolve().parents[2] / "data" / "sample" / "feature_sample.csv"


@st.cache_data
def load_data() -> pd.DataFrame:
    data = pd.read_csv(SAMPLE_PATH)
    if "year" not in data.columns and "observation_date" in data.columns:
        data["year"] = pd.to_datetime(data["observation_date"]).dt.year
    return data


df = load_data()
if "country_name" not in df.columns or "city_average_temperature" not in df.columns:
    st.error("File mẫu thiếu country_name hoặc city_average_temperature.")
    st.stop()

country_avg = (
    df.groupby("country_name", as_index=False)["city_average_temperature"]
    .mean()
    .rename(columns={"country_name": "Quốc gia", "city_average_temperature": "Nhiệt độ TB (°C)"})
    .sort_values("Nhiệt độ TB (°C)", ascending=False)
)
overall_mean = df["city_average_temperature"].mean()

st.caption(
    f"Nguồn biểu đồ: feature_sample.csv. Mỗi cột biểu diễn nhiệt độ trung bình của các quan sát thành phố trong mẫu; "
    f"đường tham chiếu ở biểu đồ so sánh là trung bình toàn bộ mẫu ({overall_mean:.2f}°C)."
)

hot, cold = st.columns(2)
with hot:
    top_hot = country_avg.head(10).sort_values("Nhiệt độ TB (°C)")
    figure_hot = px.bar(
        top_hot, x="Nhiệt độ TB (°C)", y="Quốc gia", orientation="h",
        color="Nhiệt độ TB (°C)", color_continuous_scale="YlOrRd", text_auto=".2f",
        title="🔥 10 quốc gia có nhiệt độ trung bình cao nhất",
        labels={"Nhiệt độ TB (°C)": "Nhiệt độ trung bình (°C)"},
    )
    figure_hot.update_layout(coloraxis_colorbar_title="°C", margin=dict(l=10, r=10, t=55, b=20))
    figure_hot.update_traces(textposition="outside", hovertemplate="<b>%{y}</b><br>Nhiệt độ TB: %{x:.2f}°C<extra></extra>")
    st.plotly_chart(figure_hot, use_container_width=True)
    st.caption("Chú thích: màu vàng → đỏ biểu thị nhiệt độ trung bình tăng dần; nhãn cuối cột là giá trị °C.")

with cold:
    top_cold = country_avg.tail(10).sort_values("Nhiệt độ TB (°C)", ascending=False)
    figure_cold = px.bar(
        top_cold, x="Nhiệt độ TB (°C)", y="Quốc gia", orientation="h",
        color="Nhiệt độ TB (°C)", color_continuous_scale="Blues_r", text_auto=".2f",
        title="❄️ 10 quốc gia có nhiệt độ trung bình thấp nhất",
        labels={"Nhiệt độ TB (°C)": "Nhiệt độ trung bình (°C)"},
    )
    figure_cold.update_layout(coloraxis_colorbar_title="°C", margin=dict(l=10, r=10, t=55, b=20))
    figure_cold.update_traces(textposition="outside", hovertemplate="<b>%{y}</b><br>Nhiệt độ TB: %{x:.2f}°C<extra></extra>")
    st.plotly_chart(figure_cold, use_container_width=True)
    st.caption("Chú thích: màu xanh đậm biểu thị nhiệt độ thấp hơn; nhãn cuối cột là giá trị °C.")

st.markdown("---")
st.subheader("So sánh chi tiết giữa các quốc gia")
selected_countries = st.multiselect(
    "Chọn tối đa 10 quốc gia để so sánh",
    options=country_avg["Quốc gia"].tolist(),
    default=country_avg["Quốc gia"].head(5).tolist(),
    max_selections=10,
)

if selected_countries:
    comparison = country_avg[country_avg["Quốc gia"].isin(selected_countries)].sort_values("Nhiệt độ TB (°C)")
    figure_compare = px.bar(
        comparison, x="Quốc gia", y="Nhiệt độ TB (°C)",
        color="Nhiệt độ TB (°C)", color_continuous_scale="Turbo", text_auto=".2f",
        title="So sánh nhiệt độ trung bình của các quốc gia đã chọn",
        labels={"Nhiệt độ TB (°C)": "Nhiệt độ trung bình (°C)"},
    )
    figure_compare.add_hline(
        y=overall_mean, line_dash="dash", line_color="#FFFFFF",
        annotation_text=f"Trung bình mẫu: {overall_mean:.2f}°C", annotation_position="top left",
    )
    figure_compare.update_layout(
        coloraxis_colorbar_title="°C", xaxis_tickangle=-25,
        margin=dict(l=10, r=10, t=60, b=70), showlegend=False,
    )
    figure_compare.update_traces(hovertemplate="<b>%{x}</b><br>Nhiệt độ TB: %{y:.2f}°C<extra></extra>")
    st.plotly_chart(figure_compare, use_container_width=True)
    st.info(
        "Cách đọc biểu đồ: màu và chiều cao cột cùng biểu thị nhiệt độ trung bình; "
        "đường trắng nét đứt là trung bình của toàn bộ mẫu. Cột nằm trên đường này ấm hơn trung bình mẫu."
    )
else:
    st.info("Hãy chọn ít nhất một quốc gia để hiển thị biểu đồ so sánh.")
