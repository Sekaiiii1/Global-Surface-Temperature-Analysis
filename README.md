# Climate Change: Earth Surface Temperature Analysis

Quy trình phân tích và machine learning cho bộ dữ liệu nhiệt độ bề mặt Trái Đất (Berkeley Earth):
từ khảo sát dữ liệu → PostgreSQL ETL → làm sạch → EDA → feature engineering → mô hình → ứng dụng.

> Quy ước làm việc, phân công nhóm và chi tiết yêu cầu từng notebook: xem [`AGENTS_climate_project.md`](AGENTS_climate_project.md).

## Trạng thái hiện tại

| Thành phần | Trạng thái |
|---|---|
| `notebooks/01_data_understanding.ipynb` | ✅ Hoàn thành |
| `notebooks/02_postgresql_pipeline.ipynb` + `SQL/` | ✅ Hoàn thành |
| `notebooks/03_data_cleaning.ipynb` | ✅ Hoàn thành (đọc PostgreSQL, tự fallback CSV) |
| `notebooks/04–07`, `app/`, `models/` | 🚧 Đang phát triển |

## Yêu cầu môi trường

- **Python** 3.10+ (đã kiểm thử với Python 3.13)
- **PostgreSQL** 15+ (khuyến nghị 18) — cần cho `notebooks/02`; `notebooks/03` có thể chạy không cần DB (đọc CSV)
- Git

## Cài đặt

```powershell
# 1. Tạo và kích hoạt môi trường ảo
python -m venv .venv
.\.venv\Scripts\Activate.ps1          # PowerShell (Windows)
# source .venv/bin/activate           # macOS / Linux

# 2. Cài thư viện
python -m pip install -r requirements.txt
```

## Thiết lập dữ liệu và cấu hình

1. **Dữ liệu gốc:** đặt đủ 5 file CSV vào `data/raw/`. Các file này không nằm trong git —
   xem [`data/raw/README.md`](data/raw/README.md) để biết tên file, số dòng và nguồn tải.
2. **Cấu hình PostgreSQL** (cho notebook 02, và 03 khi đọc từ DB): tạo file `.env` ở gốc dự án
   từ mẫu và điền thông tin database trên máy bạn:
   ```powershell
   Copy-Item .env.example .env
   ```
   `.env` đã được `.gitignore` bỏ qua — mỗi thành viên tự tạo, không commit, không chia sẻ mật khẩu.

## Chạy pipeline

Chạy các notebook theo đúng thứ tự, mỗi notebook chạy từ trên xuống:

```text
01_data_understanding  →  02_postgresql_pipeline  →  03_data_cleaning  →  04..07
```

- **`01`** khảo sát 5 CSV (đọc từ `data/raw/`).
- **`02`** dựng PostgreSQL ETL: staging → dimension/fact → view → aggregation → index.
  Cần `.env` và database `climate_db`. Kết thúc bằng `POSTGRESQL PIPELINE: READY` và bàn giao 5 view
  `vw_*_temperature`. Chi tiết backup/restore để chuyển máy: xem Mục 13 trong chính notebook.
- **`03`** làm sạch dữ liệu (missing / duplicate / outlier / data type) và ghi ra `data/processed/cleaned_*.csv`.
  Notebook tự chọn nguồn: **ưu tiên đọc PostgreSQL** (5 view của notebook 02); nếu không có
  `psycopg2`/`python-dotenv`/`.env`/database thì **tự fallback sang đọc CSV** trong `data/raw/`.
  Cell đầu in rõ `Nguồn dữ liệu: POSTGRESQL` hoặc `CSV`.

## Ghi chú

- **Không commit** dữ liệu lớn (`data/raw/*`) và bí mật (`.env`) — đã cấu hình trong `.gitignore`.
- File output lớn trong `data/processed/` (đặc biệt `cleaned_city.csv`) nên coi là sản phẩm tái tạo
  từ code; cân nhắc không commit các file này để tránh phình repo.
- Mọi dữ liệu đã làm sạch phải tái tạo được bằng cách chạy lại notebook, không sửa tay `data/raw/`.
