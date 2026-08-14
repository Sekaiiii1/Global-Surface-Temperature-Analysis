"""Trang Về — giới thiệu project và nhóm."""
import streamlit as st

st.set_page_config(page_title="Về dự án", page_icon="ℹ️", layout="centered")
st.title("ℹ️ Về dự án")

st.markdown("""
## Dự đoán nhiệt độ bề mặt Trái Đất tại các thành phố lớn

**Trường:** Cao đẳng FPT Polytechnic
**Môn học:** Dự án 1 — Nhóm 5, Lớp AI21302
**Giáo viên hướng dẫn:** Nguyễn Văn Long

### Thành viên nhóm
| Họ tên | Vai trò |
|---|---|
| Lương Minh Kiệt | Leader |
| Cao Tấn Phát | Database |
| Lê Bá Hiền | Data Analyst |
| Vòng Tín Phú | Web/API |
| Trần Duy Ân | Train AI/ML |

### Dataset
**Climate Change: Earth Surface Temperature Data** (Kaggle), nguồn gốc từ
nghiên cứu Berkeley Earth Surface Temperature Study — tổng hợp từ 1,6 tỷ
báo cáo nhiệt độ trên toàn thế giới.

### Công nghệ sử dụng
- **PostgreSQL** — lưu trữ, Join, Aggregation, Indexing
- **Python** (pandas, numpy, scikit-learn) — Feature Engineering, Machine Learning
- **FastAPI** — REST API phục vụ dự đoán
- **Streamlit** — Dashboard tương tác
""")