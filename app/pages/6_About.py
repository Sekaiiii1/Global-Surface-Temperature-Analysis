"""Trang giới thiệu dự án và nhóm thực hiện."""

import streamlit as st


st.set_page_config(page_title="Về dự án", page_icon="ℹ️", layout="wide")

st.markdown(
    """
    <style>
      .hero {padding: 1.2rem 1.5rem; border: 1px solid #2b6cb0; border-radius: 16px;
             background: linear-gradient(120deg, #102a43 0%, #0e1117 65%); margin-bottom: 1rem;}
      .hero h1 {margin: 0; color: #f7fafc; font-size: 2.25rem;}
      .hero p {margin: .55rem 0 0; color: #cbd5e0; font-size: 1.05rem;}
      .section-note {color: #a0aec0; margin-top: -.35rem; margin-bottom: .8rem;}
      .member-card {padding: .85rem 1rem; border: 1px solid #2d3748; border-radius: 12px;
                    background: #151923; min-height: 92px;}
      .member-card h4 {margin: 0 0 .3rem; color: #f7fafc;}
      .member-card p {margin: 0; color: #68d391;}
    </style>
    <div class="hero">
      <h1>🌍 Dự đoán nhiệt độ bề mặt Trái Đất</h1>
      <p>Hệ thống phân tích dữ liệu nhiệt độ lịch sử và ước lượng nhiệt độ trung bình khí hậu kỳ vọng theo thành phố và tháng.</p>
    </div>
    """,
    unsafe_allow_html=True,
)

metric1, metric2, metric3, metric4 = st.columns(4)
metric1.metric("Dữ liệu City raw", "8,6 triệu dòng")
metric2.metric("Sau Feature Engineering", "5,58 triệu dòng")
metric3.metric("Phạm vi dữ liệu", "1863–2013")
metric4.metric("Feature triển khai", "15")

st.markdown("---")
left, right = st.columns([1.15, 1])
with left:
    st.subheader("🎯 Mục tiêu dự án")
    st.write(
        "Nhóm xây dựng pipeline từ CSV, PostgreSQL, làm sạch dữ liệu, EDA, Feature Engineering "
        "đến Machine Learning và ứng dụng web. Mô hình sử dụng mùa vụ, địa lý, quốc gia và "
        "thống kê khí hậu lịch sử để ước lượng nhiệt độ trung bình kỳ vọng."
    )
    st.info(
        "Lưu ý: dữ liệu quan trắc kết thúc vào 09/2013. Kết quả sau mốc này là ước lượng khí hậu "
        "tham khảo, không phải dự báo thời tiết quan trắc thực tế."
    )
with right:
    st.subheader("🏫 Thông tin học phần")
    st.markdown(
        "**Trường:** Cao đẳng FPT Polytechnic\n\n"
        "**Môn học:** Dự án 1\n\n"
        "**Nhóm:** Nhóm 5 — Lớp AI21302\n\n"
        "**Giáo viên hướng dẫn:** Nguyễn Văn Long"
    )

st.markdown("---")
st.subheader("👥 Thành viên nhóm")
st.caption("Mỗi thành viên phụ trách một phần của chuỗi xử lý dữ liệu và sản phẩm triển khai.")
members = [
    ("Lương Minh Kiệt", "Leader · Điều phối và tích hợp"),
    ("Cao Tấn Phát", "Database · PostgreSQL pipeline"),
    ("Lê Bá Hiền", "Data Analyst · Cleaning và EDA"),
    ("Vòng Tín Phú", "Web/API · FastAPI và Streamlit"),
    ("Trần Duy Ân", "Train AI/ML · Feature và mô hình"),
]
for start in range(0, len(members), 3):
    columns = st.columns(3)
    for column, (name, role) in zip(columns, members[start : start + 3]):
        with column:
            st.markdown(f'<div class="member-card"><h4>{name}</h4><p>{role}</p></div>', unsafe_allow_html=True)

st.markdown("---")
data_col, tech_col = st.columns(2)
with data_col:
    st.subheader("🗂️ Dataset")
    st.markdown(
        "**Climate Change: Earth Surface Temperature Data** từ Kaggle, có nguồn gốc từ "
        "Berkeley Earth Surface Temperature Study. Dự án dùng bảng City làm bảng chính, "
        "sau đó giữ 50 quốc gia có số bản ghi nhiều nhất để xử lý và mô hình hóa."
    )
with tech_col:
    st.subheader("⚙️ Công nghệ sử dụng")
    st.markdown(
        "- **PostgreSQL** — staging, join, aggregation, index  \n"
        "- **Python** — cleaning, EDA, feature engineering, machine learning  \n"
        "- **Scikit-learn / XGBoost** — so sánh mô hình  \n"
        "- **FastAPI + Streamlit** — API và giao diện tương tác"
    )

st.markdown("---")
st.subheader("🔄 Quy trình dự án")
st.code("CSV → PostgreSQL → Cleaning → EDA → Feature Engineering → Machine Learning → FastAPI / Streamlit", language=None)
