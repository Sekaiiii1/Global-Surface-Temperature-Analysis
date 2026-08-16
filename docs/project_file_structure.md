# Sơ đồ cấu trúc tệp dự án

```text
Global-Surface-Temperature-Analysis/
│
├── app/                                      # Ứng dụng dự báo và trực quan hóa
│   ├── Prediction.py                         # Điểm khởi động Streamlit: trang Prediction
│   ├── api.py                                # FastAPI cung cấp API dự báo
│   ├── prediction_service.py                 # Dịch vụ nạp model và tạo dự báo
│   ├── .streamlit/
│   │   └── config.toml                       # Cấu hình giao diện Streamlit
│   ├── pages/
│   │   ├── 0_Data_Input.py                   # Nạp dữ liệu quan trắc mới để kiểm duyệt
│   │   ├── 1_Dashboard.py                    # Tổng quan dữ liệu và mô hình
│   │   ├── 2_Country_Analysis.py             # Phân tích theo quốc gia
│   │   ├── 3_Trend_Analysis.py               # Phân tích xu hướng thời gian
│   │   ├── 4_Insights.py                     # Các insight của dự án
│   │   └── 6_About.py                        # Thông tin dự án và nhóm
│   └── utils/                                # Hàm tái sử dụng cho ứng dụng
│       ├── data_loader.py
│       ├── feature_engineering.py
│       ├── helper.py
│       ├── preprocessing.py
│       └── visualization.py
│
├── data/                                     # Dữ liệu đầu vào và đầu ra cục bộ
│   ├── raw/                                  # Năm tệp CSV gốc từ Kaggle/Berkeley Earth
│   │   ├── GlobalTemperatures.csv
│   │   ├── GlobalLandTemperaturesByCountry.csv
│   │   ├── GlobalLandTemperaturesByState.csv
│   │   ├── GlobalLandTemperaturesByCity.csv  # Nguồn dữ liệu chính của mô hình
│   │   └── GlobalLandTemperaturesByMajorCity.csv
│   ├── processed/                            # Đầu ra cục bộ sau xử lý, không đưa lên Git
│   │   ├── cleaned_city_temperature.csv
│   │   ├── feature_engineered_data.csv.gz
│   │   ├── feature_metadata.json
│   │   ├── feature_statistics.csv.gz
│   │   └── model_comparison.csv
│   └── sample/                               # Dữ liệu mẫu phục vụ demo và kiểm thử
│       ├── demo.csv
│       └── feature_sample.csv
│
├── docs/                                     # Tài liệu báo cáo, checklist và tài liệu tham khảo
│
├── models/                                   # Artifact mô hình cục bộ, không đưa lên Git
│   ├── candidates/                           # Model ứng viên trong quá trình so sánh
│   ├── model.pkl                             # Pipeline mô hình được chọn, gồm preprocessing
│   └── model_metadata.json                   # Feature contract, metric và giới hạn dự báo
│
├── notebooks_v1/                             # Phiên bản notebook chính của dự án
│   ├── 01_data_understanding.ipynb
│   ├── 02_postgresql_pipeline.ipynb
│   ├── 03_data_cleaning.ipynb
│   ├── 04_eda_visualization.ipynb
│   ├── 05_feature_engineering.ipynb
│   ├── 06_machine_learning.ipynb
│   └── 07_prediction_demo.ipynb
│
├── notebooks_v2/                             # Phiên bản thử nghiệm/cập nhật của các notebook
│   ├── 01_data_understanding.ipynb
│   ├── 02_postgresql_pipeline.ipynb
│   ├── 03_data_cleaning.ipynb
│   ├── 04_eda_visualization.ipynb
│   ├── 05_feature_engineering.ipynb
│   ├── 06_machine_learning.ipynb
│   └── 07_prediction_demo.ipynb
│
├── reports/                                  # Sản phẩm báo cáo và hình ảnh trực quan hóa
│   ├── images/
│   │   ├── 16_model_comparison.png
│   │   ├── 17a_rolling_origin_rmse.png
│   │   ├── 17_final_model_test_actual_vs_predicted.png
│   │   ├── 18_forecast_scenario_12_months.png
│   │   └── 19_forecast_city_comparison_12_months.png
│   ├── slide-du-an-nhom-1.pptx
│   └── tai-lieu-du-an.docx
│
├── SQL/                                      # Script PostgreSQL dùng trong Notebook 02
│   ├── 01_create_tables.sql
│   ├── 02_import_data.sql
│   ├── 03_views.sql
│   ├── 04_aggregation.sql
│   └── 05_indexes.sql
│
├── prompt/                                   # Prompt/tài liệu hỗ trợ phát triển nội bộ
├── .env.example                              # Mẫu cấu hình kết nối, không chứa mật khẩu
├── .gitignore                                # Quy tắc loại trừ dữ liệu và artifact cục bộ
├── AGENTS_climate_project.md                 # Quy ước phát triển dự án
├── project_file_structure.md                 # Tài liệu sơ đồ cấu trúc này
├── README.md                                 # Hướng dẫn cài đặt và chạy dự án
└── requirements.txt                          # Danh sách thư viện Python
```

## Luồng liên kết giữa các thành phần

```text
data/raw
   │
   ▼
notebooks_v1/01_data_understanding.ipynb
   │  Khảo sát dữ liệu và xác định bảng City là nguồn chính
   ▼
notebooks_v1/02_postgresql_pipeline.ipynb  ──► SQL/ ──► PostgreSQL
   │  Import, cắt 50 quốc gia, view, join, aggregation và index
   ▼
notebooks_v1/03_data_cleaning.ipynb
   │  Làm sạch, kiểm tra missing value và phân tích outlier
   ▼
notebooks_v1/04_eda_visualization.ipynb ──► reports/images/
   │  EDA, biểu đồ và insight
   ▼
notebooks_v1/05_feature_engineering.ipynb ──► data/processed/feature_metadata.json
   │  Feature contract và thống kê khí hậu nền
   ▼
notebooks_v1/06_machine_learning.ipynb ──► models/model.pkl + model_metadata.json
   │  Huấn luyện, backtest, đánh giá và biểu đồ kịch bản dự báo
   ▼
app/Prediction.py + app/api.py ──► Streamlit + FastAPI
```

## Vai trò các thư mục chính

| Thành phần | Vai trò trong dự án |
|---|---|
| `data/raw/` | Lưu năm tệp CSV gốc để có thể truy vết nguồn dữ liệu. |
| `data/processed/` | Lưu đầu ra cục bộ sau làm sạch, Feature Engineering và so sánh mô hình. |
| `notebooks_v1/` | Lưu pipeline notebook chính, có thứ tự chạy từ 01 đến 07. |
| `notebooks_v2/` | Lưu phiên bản cập nhật hoặc thử nghiệm, tách biệt với phiên bản trình bày chính. |
| `SQL/` | Lưu script chạy trong PostgreSQL/pgAdmin 4. |
| `models/` | Lưu Pipeline mô hình, metadata và model ứng viên ở máy cục bộ. |
| `app/` | Cung cấp FastAPI và giao diện Streamlit cho phân tích, nhập dữ liệu và dự báo. |
| `reports/` | Lưu hình ảnh, slide và tài liệu sử dụng trong báo cáo. |
| `docs/` | Lưu tài liệu báo cáo, checklist và tài liệu tham khảo. |

## Tệp cục bộ không đưa lên Git

- `.env`: chứa cấu hình và thông tin kết nối PostgreSQL của từng máy.
- `.venv/`: môi trường Python cục bộ, có thể tạo lại bằng `requirements.txt`.
- `data/raw/`, `data/processed/` và `data/incoming/`: dữ liệu nguồn, dữ liệu xử lý hoặc dữ liệu do người dùng nạp.
- `models/`: artifact mô hình có thể lớn; mô hình được tái tạo bằng Notebook 06 hoặc chia sẻ qua kênh lưu trữ phù hợp.
- `__pycache__/` và `.ipynb_checkpoints/`: tệp phát sinh tự động khi chạy Python/Jupyter.

> Sơ đồ này phản ánh cấu trúc cục bộ hiện tại của dự án. Các dữ liệu lớn, model artifact và thông tin nhạy cảm được loại trừ khỏi Git để bảo đảm an toàn thông tin và tránh vượt giới hạn dung lượng repository.
