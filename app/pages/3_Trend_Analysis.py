"""Trang phân tích xu hướng nhiệt độ theo thời gian."""
from pathlib import Path

import numpy as np
import pandas as pd
import plotly.express as px
import plotly.graph_objects as go
import streamlit as st


st.set_page_config(page_title="Phân tích xu hướng", page_icon="📈", layout="wide")

st.markdown(
    """
    <style>
        .trend-hero {
            padding: 1.8rem 2rem; border-radius: 18px;
            background: linear-gradient(115deg, #132c45 0%, #17223f 52%, #263653 100%);
            border: 1px solid rgba(117, 192, 255, .25); margin-bottom: 1.25rem;
        }
        .trend-hero h1 { margin: 0; font-size: 2.35rem; }
        .trend-hero p { margin: .45rem 0 0; color: #c4d7eb; font-size: 1.05rem; }
        .section-label { color: #8eb8dc; font-size: .85rem; font-weight: 700;
                         letter-spacing: .08em; text-transform: uppercase; }
        .insight-card {
            padding: 1rem 1.15rem; min-height: 122px; border-radius: 13px;
            border-left: 4px solid #54b8ff; background: rgba(49, 92, 133, .18);
        }
        .insight-card h4 { margin: 0 0 .35rem; }
        .insight-card p { margin: 0; color: #c7d4e2; }
    </style>
    <div class="trend-hero">
        <h1>📈 Bản đồ xu hướng nhiệt độ</h1>
        <p>Khám phá mức nhiệt trung bình theo năm, xu hướng dài hạn và biến động theo từng thập kỷ.</p>
    </div>
    """,
    unsafe_allow_html=True,
)

SAMPLE_PATH = (
    Path(__file__).resolve().parent.parent.parent / "data" / "sample" / "feature_sample.csv"
)
TARGET_COL = "city_average_temperature"


@st.cache_data
def load_data() -> pd.DataFrame:
    """Đọc mẫu dữ liệu đã xây dựng feature để biểu đồ phản hồi nhanh."""
    data = pd.read_csv(SAMPLE_PATH)
    if "year" not in data.columns and "observation_date" in data.columns:
        data["year"] = pd.to_datetime(data["observation_date"], errors="coerce").dt.year
    return data.dropna(subset=["year", TARGET_COL]).copy()


try:
    df = load_data()
except FileNotFoundError:
    st.error("Không tìm thấy data/sample/feature_sample.csv. Hãy chạy notebook tạo feature trước.")
    st.stop()

if TARGET_COL not in df.columns or "year" not in df.columns:
    st.error("Thiếu cột `year` hoặc `city_average_temperature` trong dữ liệu mẫu.")
    st.stop()

year_min, year_max = int(df["year"].min()), int(df["year"].max())
st.markdown('<div class="section-label">Bộ lọc phân tích</div>', unsafe_allow_html=True)
left_filter, right_filter = st.columns([4, 1])
with left_filter:
    year_range = st.slider(
        "Khoảng năm quan sát",
        min_value=year_min,
        max_value=year_max,
        value=(year_min, year_max),
        help="Biểu đồ được tính lại theo khoảng năm bạn chọn.",
    )
with right_filter:
    show_rolling = st.toggle("Đường làm mượt 10 năm", value=True)

filtered = df.loc[df["year"].between(*year_range)].copy()
yearly_avg = (
    filtered.groupby("year", as_index=False)[TARGET_COL]
    .mean()
    .sort_values("year")
)

if yearly_avg.empty:
    st.warning("Không có dữ liệu trong khoảng năm đã chọn.")
    st.stop()

start_value = yearly_avg[TARGET_COL].iloc[0]
end_value = yearly_avg[TARGET_COL].iloc[-1]
change = end_value - start_value
min_row = yearly_avg.loc[yearly_avg[TARGET_COL].idxmin()]
max_row = yearly_avg.loc[yearly_avg[TARGET_COL].idxmax()]

if len(yearly_avg) >= 2:
    slope, intercept = np.polyfit(yearly_avg["year"], yearly_avg[TARGET_COL], 1)
    yearly_avg["linear_trend"] = yearly_avg["year"] * slope + intercept
else:
    slope = 0.0
    yearly_avg["linear_trend"] = yearly_avg[TARGET_COL]

yearly_avg["rolling_10y"] = yearly_avg[TARGET_COL].rolling(
    window=min(10, len(yearly_avg)), min_periods=1, center=True
).mean()

st.markdown('<div class="section-label">Tóm tắt nhanh</div>', unsafe_allow_html=True)
metric_1, metric_2, metric_3, metric_4 = st.columns(4)
metric_1.metric(f"Thay đổi {year_range[0]}–{year_range[1]}", f"{change:+.2f} °C")
metric_2.metric("Xu hướng tuyến tính", f"{slope * 10:+.3f} °C / thập kỷ")
metric_3.metric("Năm nóng nhất", f"{int(max_row['year'])}", f"{max_row[TARGET_COL]:.2f} °C")
metric_4.metric("Năm lạnh nhất", f"{int(min_row['year'])}", f"{min_row[TARGET_COL]:.2f} °C")

st.markdown("### Diễn biến nhiệt độ theo năm")
st.caption(
    "Đường xanh là nhiệt độ trung bình theo năm của các quan sát trong dữ liệu mẫu; "
    "đường cam thể hiện xu hướng tuyến tính trên đúng khoảng năm đang chọn."
)

trend_fig = go.Figure()
trend_fig.add_trace(
    go.Scatter(
        x=yearly_avg["year"], y=yearly_avg[TARGET_COL], mode="lines+markers",
        name="Nhiệt độ trung bình năm", line=dict(color="#68c5ff", width=2),
        marker=dict(size=5, color="#8bd3ff"),
        hovertemplate="Năm %{x}<br>Nhiệt độ: %{y:.2f} °C<extra></extra>",
    )
)
trend_fig.add_trace(
    go.Scatter(
        x=yearly_avg["year"], y=yearly_avg["linear_trend"], mode="lines",
        name="Xu hướng tuyến tính", line=dict(color="#ffb84c", width=3, dash="dash"),
        hovertemplate="Năm %{x}<br>Xu hướng: %{y:.2f} °C<extra></extra>",
    )
)
if show_rolling:
    trend_fig.add_trace(
        go.Scatter(
            x=yearly_avg["year"], y=yearly_avg["rolling_10y"], mode="lines",
            name="Trung bình trượt 10 năm", line=dict(color="#e878d4", width=2),
            hovertemplate="Năm %{x}<br>TB trượt: %{y:.2f} °C<extra></extra>",
        )
    )

trend_fig.add_annotation(
    x=int(max_row["year"]), y=max_row[TARGET_COL], text="Đỉnh nhiệt", showarrow=True,
    arrowhead=2, ax=25, ay=-38, font=dict(color="#ffcb75"), arrowcolor="#ffcb75",
)
trend_fig.update_layout(
    height=475, margin=dict(l=8, r=8, t=25, b=10), template="plotly_dark",
    legend=dict(orientation="h", yanchor="bottom", y=1.02, xanchor="left", x=0),
    xaxis_title="Năm", yaxis_title="Nhiệt độ trung bình (°C)",
    paper_bgcolor="rgba(0,0,0,0)", plot_bgcolor="rgba(16, 24, 39, .52)",
)
trend_fig.update_xaxes(showgrid=False)
trend_fig.update_yaxes(gridcolor="rgba(168, 190, 215, .17)", zeroline=False)
st.plotly_chart(trend_fig, use_container_width=True)

col_decade, col_variability = st.columns(2)
with col_decade:
    st.markdown("### Nhiệt độ theo thập kỷ")
    st.caption("So sánh mức nhiệt nền giữa các thập kỷ trong khoảng đang chọn.")
    decade_avg = yearly_avg.assign(decade=(yearly_avg["year"] // 10) * 10).groupby(
        "decade", as_index=False
    )[TARGET_COL].mean()
    decade_avg["label"] = decade_avg["decade"].astype(str) + "s"
    decade_fig = px.bar(
        decade_avg, x="label", y=TARGET_COL, color=TARGET_COL, text_auto=".2f",
        color_continuous_scale=["#355c7d", "#6c5b7b", "#c06c84", "#f8b195"],
        labels={"label": "Thập kỷ", TARGET_COL: "Nhiệt độ (°C)"},
    )
    decade_fig.update_layout(
        height=360, template="plotly_dark", margin=dict(l=8, r=8, t=15, b=5),
        coloraxis_showscale=False, paper_bgcolor="rgba(0,0,0,0)",
        plot_bgcolor="rgba(16, 24, 39, .52)",
    )
    decade_fig.update_xaxes(showgrid=False)
    decade_fig.update_yaxes(gridcolor="rgba(168, 190, 215, .17)", title=None)
    st.plotly_chart(decade_fig, use_container_width=True)

with col_variability:
    st.markdown("### Mức lệch so với xu hướng")
    st.caption("Giá trị dương/lệch lên trên đường 0 nghĩa là năm đó ấm hơn mức xu hướng ước tính.")
    yearly_avg["trend_residual"] = yearly_avg[TARGET_COL] - yearly_avg["linear_trend"]
    residual_fig = go.Figure(
        go.Bar(
            x=yearly_avg["year"], y=yearly_avg["trend_residual"],
            marker_color=np.where(yearly_avg["trend_residual"] >= 0, "#ff8a65", "#67b7dc"),
            name="Lệch so với xu hướng",
            hovertemplate="Năm %{x}<br>Lệch: %{y:+.2f} °C<extra></extra>",
        )
    )
    residual_fig.add_hline(y=0, line_color="#d5dce5", line_width=1)
    residual_fig.update_layout(
        height=360, template="plotly_dark", margin=dict(l=8, r=8, t=15, b=5),
        showlegend=False, paper_bgcolor="rgba(0,0,0,0)",
        plot_bgcolor="rgba(16, 24, 39, .52)", xaxis_title="Năm", yaxis_title="Lệch (°C)",
    )
    residual_fig.update_xaxes(showgrid=False)
    residual_fig.update_yaxes(gridcolor="rgba(168, 190, 215, .17)", zeroline=False)
    st.plotly_chart(residual_fig, use_container_width=True)

direction = "ấm lên" if slope > 0 else "mát đi" if slope < 0 else "ổn định"
st.markdown("### Diễn giải kết quả")
insight_left, insight_right = st.columns(2)
with insight_left:
    st.markdown(
        f'''<div class="insight-card"><h4>📌 Tín hiệu dài hạn</h4><p>Trong giai đoạn {year_range[0]}–{year_range[1]}, đường xu hướng ước tính cho thấy nhiệt độ {direction} khoảng <b>{abs(slope * 10):.3f} °C mỗi thập kỷ</b>.</p></div>''',
        unsafe_allow_html=True,
    )
with insight_right:
    st.markdown(
        f'''<div class="insight-card"><h4>🔎 Cách đọc đúng</h4><p>Chênh lệch đầu–cuối kỳ là <b>{change:+.2f} °C</b>. Đây là thống kê trên dữ liệu thành phố trong mẫu, không phải tốc độ nóng lên tuyệt đối của toàn cầu.</p></div>''',
        unsafe_allow_html=True,
    )

st.info(
    "Nguồn biểu đồ: `data/sample/feature_sample.csv`. Các giá trị là trung bình của dữ liệu mẫu theo năm; "
    "chúng dùng để khám phá xu hướng, không thay thế dữ liệu khí hậu quan trắc toàn cầu chính thức."
)
