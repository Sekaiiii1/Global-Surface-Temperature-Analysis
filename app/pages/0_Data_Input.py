"""Tiếp nhận dữ liệu quan trắc mới để chuẩn bị cập nhật và tái huấn luyện model."""
from datetime import date, datetime, timezone
from pathlib import Path

import pandas as pd
import streamlit as st

from prediction_service import get_city_list, load_location_stats


st.set_page_config(page_title="Bổ sung dữ liệu", page_icon="🧩", layout="wide")

PROJECT_ROOT = Path(__file__).resolve().parents[2]
PENDING_DATA_PATH = PROJECT_ROOT / "data" / "incoming" / "city_temperature_updates.csv"
GAP_START = pd.Timestamp("2013-10-01")
CURRENT_MONTH = pd.Timestamp(date.today().replace(day=1))

REQUIRED_COLUMNS = [
    "observation_date",
    "city_name",
    "country_name",
    "latitude",
    "longitude",
    "city_average_temperature",
]
OPTIONAL_COLUMNS = ["city_average_temperature_uncertainty", "data_source"]
OUTPUT_COLUMNS = REQUIRED_COLUMNS + OPTIONAL_COLUMNS
BUSINESS_KEY = [
    "observation_date",
    "city_name",
    "country_name",
    "latitude",
    "longitude",
]

st.markdown(
    """
    <style>
        .update-hero {
            position: relative; overflow: hidden; padding: 2.1rem 2.3rem; border-radius: 20px;
            background: linear-gradient(118deg, #26335b 0%, #37466e 48%, #1e6266 100%);
            border: 1px solid rgba(130, 219, 215, .35); margin-bottom: 1.25rem;
        }
        .update-hero:after { content: '↻'; position: absolute; right: 4%; top: -62px;
                             color: rgba(255,255,255,.12); font-size: 12rem; }
        .update-hero h1 { margin: 0; font-size: 2.4rem; position: relative; }
        .update-hero p { margin: .55rem 0 0; color: #d8e9ef; max-width: 880px;
                         font-size: 1.05rem; position: relative; }
        .purpose-card { min-height: 128px; height: 100%; padding: 1rem 1.1rem; border-radius: 14px;
                        background: rgba(42, 54, 86, .5); border: 1px solid rgba(138, 180, 220, .2); }
        .purpose-card h4 { margin: .25rem 0 .35rem; }
        .purpose-card p { margin: 0; color: #c8d4e1; font-size: .91rem; }
        .purpose-tag { color: #6fdccc; font-size: .76rem; font-weight: 800; letter-spacing: .09em; }
        .flow-card { padding: .9rem 1rem; min-height: 104px; border-radius: 13px;
                     background: linear-gradient(145deg, rgba(35,70,91,.48), rgba(37,48,77,.48));
                     border-top: 3px solid #63d2c2; }
        .flow-card b { color: #85e5d7; }
        .flow-card p { margin: .3rem 0 0; color: #c7d4df; font-size: .88rem; }
        .contract-box { padding: 1rem 1.15rem; border-radius: 13px;
                        background: rgba(53, 67, 105, .28); border-left: 4px solid #82aaff; }
        .contract-box h4 { margin: 0 0 .3rem; }
        .contract-box p { margin: 0; color: #cbd4e3; }
    </style>
    <div class="update-hero">
        <h1>🧩 Bổ sung dữ liệu quan trắc mới</h1>
        <p>Lấp khoảng trống dữ liệu thành phố từ tháng 10/2013 đến hiện tại, kiểm tra chất lượng và đưa dữ liệu hợp lệ vào vùng chờ tái huấn luyện mô hình.</p>
    </div>
    """,
    unsafe_allow_html=True,
)

card_1, card_2, card_3 = st.columns(3)
card_1.markdown(
    '<div class="purpose-card"><div class="purpose-tag">MỤC ĐÍCH</div><h4>Lấp khoảng trống sau 2013</h4><p>Tiếp nhận nhiệt độ trung bình tháng đã quan trắc, không tiếp nhận kết quả do model tự dự đoán.</p></div>',
    unsafe_allow_html=True,
)
card_2.markdown(
    '<div class="purpose-card"><div class="purpose-tag">KIỂM SOÁT</div><h4>Chặn dữ liệu không hợp lệ</h4><p>Kiểm tra ngày, tọa độ, nhiệt độ, dòng trùng và mức độ liên tục theo thời gian.</p></div>',
    unsafe_allow_html=True,
)
card_3.markdown(
    '<div class="purpose-card"><div class="purpose-tag">KẾT QUẢ</div><h4>Chuẩn bị tái huấn luyện</h4><p>Dữ liệu đạt chuẩn được lưu vào vùng chờ; model chỉ được thay thế sau khi huấn luyện và đánh giá lại.</p></div>',
    unsafe_allow_html=True,
)

st.markdown("### Quy trình cập nhật an toàn")
flow_columns = st.columns(5)
flow_items = [
    ("01", "Nhập quan trắc", "Nhập một dòng hoặc tải CSV dữ liệu thật."),
    ("02", "Kiểm tra", "Phát hiện sai định dạng, trùng và tháng thiếu."),
    ("03", "Lưu vùng chờ", "Không ghi thẳng vào model đang phục vụ."),
    ("04", "Tái huấn luyện", "Chạy lại Feature Engineering và Notebook 06."),
    ("05", "Đánh giá & phát hành", "Chỉ thay model khi metric mới tốt hơn."),
]
for column, (number, title, description) in zip(flow_columns, flow_items):
    column.markdown(
        f'<div class="flow-card"><b>BƯỚC {number}</b><h4>{title}</h4><p>{description}</p></div>',
        unsafe_allow_html=True,
    )


@st.cache_data(show_spinner=False)
def load_reference_locations() -> pd.DataFrame:
    """Lấy một bản ghi tọa độ duy nhất cho mỗi thành phố trong model hiện tại."""
    stats = load_location_stats()
    return (
        stats[["city_name", "country_name", "latitude", "longitude"]]
        .drop_duplicates()
        .sort_values(["country_name", "city_name"])
        .reset_index(drop=True)
    )


def add_issue(reasons: pd.Series, mask: pd.Series, message: str) -> pd.Series:
    """Nối thông báo lỗi vào đúng các dòng vi phạm điều kiện."""
    reasons.loc[mask] = reasons.loc[mask].apply(
        lambda current: f"{current}; {message}" if current else message
    )
    return reasons


def gap_summary(valid_data: pd.DataFrame) -> pd.DataFrame:
    """Thống kê các tháng còn thiếu từ 10/2013 đến tháng mới nhất của từng vị trí."""
    rows = []
    if valid_data.empty:
        return pd.DataFrame()

    group_columns = ["city_name", "country_name", "latitude", "longitude"]
    for key, group in valid_data.groupby(group_columns, dropna=False):
        present = set(group["observation_date"].dt.to_period("M"))
        last_period = group["observation_date"].max().to_period("M")
        expected = pd.period_range(GAP_START.to_period("M"), last_period, freq="M")
        missing = [period for period in expected if period not in present]
        city, country, latitude, longitude = key
        rows.append(
            {
                "city_name": city,
                "country_name": country,
                "latitude": latitude,
                "longitude": longitude,
                "latest_observation": group["observation_date"].max().date(),
                "months_expected": len(expected),
                "months_supplied": len(present),
                "months_missing": len(missing),
                "completeness_percent": round(100 * len(present) / len(expected), 2),
                "first_missing_months": ", ".join(str(item) for item in missing[:6]),
            }
        )
    return pd.DataFrame(rows).sort_values(
        ["months_missing", "country_name", "city_name"], ascending=[False, True, True]
    )


def validate_observations(raw_data: pd.DataFrame) -> tuple[pd.DataFrame, pd.DataFrame, pd.DataFrame]:
    """Chuẩn hóa dữ liệu tháng và tách dòng hợp lệ, dòng lỗi, thống kê tháng thiếu."""
    missing_columns = [column for column in REQUIRED_COLUMNS if column not in raw_data.columns]
    if missing_columns:
        raise ValueError(f"Thiếu cột bắt buộc: {', '.join(missing_columns)}")

    data = raw_data.copy()
    data["source_row"] = range(2, len(data) + 2)
    for column in OPTIONAL_COLUMNS:
        if column not in data.columns:
            data[column] = pd.NA

    data["observation_date"] = pd.to_datetime(data["observation_date"], errors="coerce")
    for column in ["city_name", "country_name", "data_source"]:
        data[column] = data[column].astype("string").str.strip()
    for column in [
        "latitude",
        "longitude",
        "city_average_temperature",
        "city_average_temperature_uncertainty",
    ]:
        data[column] = pd.to_numeric(data[column], errors="coerce")

    reasons = pd.Series("", index=data.index, dtype="string")
    reasons = add_issue(reasons, data["observation_date"].isna(), "Ngày không hợp lệ")
    valid_date = data["observation_date"].notna()
    reasons = add_issue(
        reasons,
        valid_date & (data["observation_date"].dt.day != 1),
        "Ngày phải là ngày đầu tháng (YYYY-MM-01)",
    )
    reasons = add_issue(
        reasons,
        valid_date & (data["observation_date"] < GAP_START),
        "Chỉ tiếp nhận dữ liệu từ 2013-10-01",
    )
    reasons = add_issue(
        reasons,
        valid_date & (data["observation_date"] > CURRENT_MONTH),
        "Không được dùng quan trắc ở tương lai",
    )
    reasons = add_issue(reasons, data["city_name"].isna() | data["city_name"].eq(""), "Thiếu tên thành phố")
    reasons = add_issue(reasons, data["country_name"].isna() | data["country_name"].eq(""), "Thiếu tên quốc gia")
    reasons = add_issue(
        reasons,
        data["latitude"].isna() | ~data["latitude"].between(-90, 90),
        "Vĩ độ phải nằm trong [-90, 90]",
    )
    reasons = add_issue(
        reasons,
        data["longitude"].isna() | ~data["longitude"].between(-180, 180),
        "Kinh độ phải nằm trong [-180, 180]",
    )
    reasons = add_issue(
        reasons,
        data["city_average_temperature"].isna()
        | ~data["city_average_temperature"].between(-90, 60),
        "Nhiệt độ phải nằm trong [-90, 60] °C",
    )
    reasons = add_issue(
        reasons,
        data["city_average_temperature_uncertainty"].notna()
        & (data["city_average_temperature_uncertainty"] < 0),
        "Độ bất định không được âm",
    )
    duplicate_mask = data.duplicated(BUSINESS_KEY, keep=False)
    reasons = add_issue(reasons, duplicate_mask, "Trùng khóa thành phố-tháng trong file")

    data["validation_error"] = reasons
    rejected = data.loc[data["validation_error"].ne("")].copy()
    accepted = data.loc[data["validation_error"].eq(""), OUTPUT_COLUMNS].copy()
    accepted["data_source"] = accepted["data_source"].fillna("user_observation")
    accepted = accepted.sort_values(BUSINESS_KEY).reset_index(drop=True)
    gaps = gap_summary(accepted)
    return accepted, rejected, gaps


def save_pending_observations(new_data: pd.DataFrame) -> tuple[int, int, int]:
    """Gộp dữ liệu hợp lệ vào vùng chờ; bản mới thay thế cùng khóa nếu người dùng sửa số liệu."""
    PENDING_DATA_PATH.parent.mkdir(parents=True, exist_ok=True)
    if PENDING_DATA_PATH.exists():
        existing = pd.read_csv(PENDING_DATA_PATH, parse_dates=["observation_date"])
    else:
        existing = pd.DataFrame(columns=OUTPUT_COLUMNS + ["ingested_at_utc"])

    existing_keys = set(
        map(tuple, existing.reindex(columns=BUSINESS_KEY).astype(str).to_numpy())
    )
    new_keys = set(map(tuple, new_data[BUSINESS_KEY].astype(str).to_numpy()))
    replaced = len(existing_keys & new_keys)
    inserted = len(new_keys - existing_keys)

    prepared = new_data.copy()
    prepared["ingested_at_utc"] = datetime.now(timezone.utc).isoformat()
    combined = pd.concat([existing, prepared], ignore_index=True)
    combined = combined.drop_duplicates(BUSINESS_KEY, keep="last").sort_values(BUSINESS_KEY)
    combined.to_csv(PENDING_DATA_PATH, index=False, encoding="utf-8-sig")
    return inserted, replaced, len(combined)


try:
    reference_locations = load_reference_locations()
    location_labels = get_city_list()
except FileNotFoundError as error:
    st.error(f"❌ {error}")
    st.stop()

manual_tab, csv_tab, contract_tab = st.tabs(
    ["✍️ Thêm một quan trắc", "📂 Tải dữ liệu CSV", "📋 Cấu trúc dữ liệu"]
)

with manual_tab:
    st.markdown("### Bổ sung một tháng cho thành phố đã có")
    st.caption("Phù hợp khi cần thêm hoặc sửa một quan trắc. Giá trị phải là số đo thực tế theo tháng.")
    month_options = list(pd.period_range(GAP_START, CURRENT_MONTH, freq="M"))[::-1]
    with st.container(border=True):
        with st.form("manual_observation_form"):
            selected_location = st.selectbox("Thành phố", location_labels)
            month_col, temp_col, uncertainty_col = st.columns(3)
            with month_col:
                selected_period = st.selectbox(
                    "Tháng quan trắc",
                    month_options,
                    format_func=lambda value: f"Tháng {value.month:02d}/{value.year}",
                )
            with temp_col:
                observed_temperature = st.number_input(
                    "Nhiệt độ trung bình tháng (°C)", min_value=-90.0, max_value=60.0,
                    value=25.0, step=0.1,
                )
            with uncertainty_col:
                observed_uncertainty = st.number_input(
                    "Độ bất định (°C, nếu có)", min_value=0.0, value=0.0, step=0.01,
                )
            data_source = st.text_input(
                "Nguồn dữ liệu",
                placeholder="Ví dụ: cơ quan khí tượng, trạm quan trắc, URL dataset...",
                help="Nên ghi rõ nguồn để dữ liệu có thể được kiểm chứng trước khi huấn luyện.",
            )
            manual_submit = st.form_submit_button("🔎 Kiểm tra quan trắc", width="stretch")

    if manual_submit:
        city, country = selected_location.rsplit(" (", 1)
        country = country.rstrip(")")
        location = reference_locations.loc[
            reference_locations["city_name"].eq(city)
            & reference_locations["country_name"].eq(country)
        ].iloc[0]
        manual_data = pd.DataFrame(
            [
                {
                    "observation_date": selected_period.to_timestamp(),
                    "city_name": city,
                    "country_name": country,
                    "latitude": location["latitude"],
                    "longitude": location["longitude"],
                    "city_average_temperature": observed_temperature,
                    "city_average_temperature_uncertainty": observed_uncertainty,
                    "data_source": data_source or "manual_user_observation",
                }
            ]
        )
        accepted, rejected, gaps = validate_observations(manual_data)
        st.session_state["validated_updates"] = accepted
        st.session_state["rejected_updates"] = rejected
        st.session_state["gap_report"] = gaps
        st.session_state["validation_source"] = "nhập thủ công"

with csv_tab:
    st.markdown("### Tải file quan trắc theo tháng")
    st.caption("Một dòng tương ứng một thành phố tại một tháng. File có thể chứa thành phố cũ hoặc thành phố mới.")

    example = pd.DataFrame(
        [
            {
                "observation_date": "2013-10-01",
                "city_name": "Hanoi",
                "country_name": "Vietnam",
                "latitude": 21.03,
                "longitude": 105.85,
                "city_average_temperature": 24.8,
                "city_average_temperature_uncertainty": 0.25,
                "data_source": "Example weather station",
            },
            {
                "observation_date": "2013-11-01",
                "city_name": "Hanoi",
                "country_name": "Vietnam",
                "latitude": 21.03,
                "longitude": 105.85,
                "city_average_temperature": 21.7,
                "city_average_temperature_uncertainty": 0.22,
                "data_source": "Example weather station",
            },
        ]
    )
    template_col, upload_col = st.columns([1, 1.6], gap="large")
    with template_col:
        st.markdown(
            '<div class="contract-box"><h4>1. Tải mẫu chuẩn</h4><p>Giữ nguyên tên cột. Ngày quan trắc luôn là ngày đầu tháng theo định dạng YYYY-MM-01.</p></div>',
            unsafe_allow_html=True,
        )
        st.download_button(
            "⬇️ Tải CSV mẫu",
            example.to_csv(index=False).encode("utf-8-sig"),
            file_name="mau_bo_sung_nhiet_do_thanh_pho.csv",
            mime="text/csv",
            width="stretch",
        )
    with upload_col:
        st.markdown(
            '<div class="contract-box"><h4>2. Tải dữ liệu quan trắc</h4><p>Hệ thống chỉ kiểm tra và đưa dữ liệu hợp lệ vào vùng chờ; chưa tự động thay model đang hoạt động.</p></div>',
            unsafe_allow_html=True,
        )
        uploaded_file = st.file_uploader("Chọn file CSV", type=["csv"], label_visibility="collapsed")

    if uploaded_file is not None:
        try:
            uploaded_data = pd.read_csv(uploaded_file)
        except (UnicodeDecodeError, pd.errors.ParserError) as error:
            st.error(f"❌ Không thể đọc CSV: {error}")
            st.stop()

        if len(uploaded_data) > 100_000:
            st.error("File vượt quá 100.000 dòng. Hãy chia nhỏ dữ liệu trước khi tải lên.")
        else:
            st.markdown("#### Xem trước dữ liệu")
            st.dataframe(uploaded_data.head(20), width="stretch", hide_index=True)
            if st.button("🔎 Kiểm tra chất lượng dữ liệu", type="primary", width="stretch"):
                try:
                    accepted, rejected, gaps = validate_observations(uploaded_data)
                except ValueError as error:
                    st.error(f"❌ {error}")
                else:
                    st.session_state["validated_updates"] = accepted
                    st.session_state["rejected_updates"] = rejected
                    st.session_state["gap_report"] = gaps
                    st.session_state["validation_source"] = uploaded_file.name

with contract_tab:
    st.markdown("### Data contract cho dữ liệu cập nhật")
    contract = pd.DataFrame(
        [
            ["observation_date", "Bắt buộc", "Ngày đầu tháng, từ 2013-10-01 đến hiện tại"],
            ["city_name", "Bắt buộc", "Tên thành phố; dùng nhất quán giữa các tháng"],
            ["country_name", "Bắt buộc", "Tên quốc gia; dùng nhất quán với pipeline"],
            ["latitude", "Bắt buộc", "Vĩ độ trong [-90, 90]"],
            ["longitude", "Bắt buộc", "Kinh độ trong [-180, 180]"],
            ["city_average_temperature", "Bắt buộc", "Nhiệt độ trung bình tháng đã quan trắc, trong [-90, 60] °C"],
            ["city_average_temperature_uncertainty", "Không bắt buộc", "Độ bất định phép đo, không âm"],
            ["data_source", "Khuyến nghị", "Tên trạm, tổ chức hoặc URL nguồn dữ liệu"],
        ],
        columns=["Cột", "Yêu cầu", "Ý nghĩa và điều kiện"],
    )
    st.dataframe(contract, width="stretch", hide_index=True)
    st.warning(
        "Không được dùng nhiệt độ do chính model hiện tại dự đoán để làm nhãn huấn luyện. "
        "Việc đó tạo vòng lặp tự củng cố sai số thay vì bổ sung kiến thức mới."
    )

if "validated_updates" in st.session_state:
    accepted_data = st.session_state["validated_updates"]
    rejected_data = st.session_state["rejected_updates"]
    gap_report = st.session_state["gap_report"]

    st.markdown("---")
    st.markdown("## Kết quả kiểm tra dữ liệu")
    accepted_metric, rejected_metric, city_metric, gap_metric = st.columns(4)
    accepted_metric.metric("Dòng đạt chuẩn", f"{len(accepted_data):,}")
    rejected_metric.metric("Dòng bị từ chối", f"{len(rejected_data):,}")
    city_metric.metric(
        "Số thành phố",
        f"{accepted_data[['city_name', 'country_name']].drop_duplicates().shape[0]:,}"
        if not accepted_data.empty else "0",
    )
    total_gaps = int(gap_report["months_missing"].sum()) if not gap_report.empty else 0
    gap_metric.metric("Tháng vẫn còn thiếu", f"{total_gaps:,}")
    st.caption(f"Nguồn vừa kiểm tra: {st.session_state.get('validation_source', 'không xác định')}")

    valid_tab, rejected_tab, gap_tab = st.tabs(
        ["✅ Dữ liệu đạt chuẩn", "❌ Dòng cần sửa", "🗓️ Khoảng trống còn lại"]
    )
    with valid_tab:
        if accepted_data.empty:
            st.warning("Không có dòng nào đạt điều kiện để lưu.")
        else:
            st.dataframe(accepted_data, width="stretch", hide_index=True)
            st.download_button(
                "⬇️ Tải dữ liệu đã chuẩn hóa",
                accepted_data.to_csv(index=False).encode("utf-8-sig"),
                file_name="city_temperature_updates_validated.csv",
                mime="text/csv",
                width="stretch",
            )
    with rejected_tab:
        if rejected_data.empty:
            st.success("Không có dòng lỗi.")
        else:
            display_columns = ["source_row"] + OUTPUT_COLUMNS + ["validation_error"]
            st.dataframe(rejected_data[display_columns], width="stretch", hide_index=True)
    with gap_tab:
        if gap_report.empty:
            st.info("Chưa có dữ liệu hợp lệ để phân tích tính liên tục.")
        else:
            st.dataframe(gap_report, width="stretch", hide_index=True)
            st.caption(
                "Khoảng trống được tính từ 10/2013 đến tháng mới nhất mà file cung cấp cho từng thành phố. "
                "Danh sách chỉ hiển thị sáu tháng thiếu đầu tiên để bảng dễ đọc."
            )

    if not accepted_data.empty:
        st.markdown("### Đưa dữ liệu vào vùng chờ tái huấn luyện")
        confirmed = st.checkbox(
            "Tôi xác nhận đây là dữ liệu quan trắc thực tế có nguồn, không phải nhiệt độ do model tạo ra."
        )
        if st.button(
            "💾 Lưu dữ liệu hợp lệ vào vùng chờ",
            type="primary",
            width="stretch",
            disabled=not confirmed,
        ):
            inserted, replaced, total = save_pending_observations(accepted_data)
            st.success(
                f"Đã lưu vùng chờ: {inserted:,} dòng mới, {replaced:,} dòng được cập nhật; "
                f"tổng cộng {total:,} dòng."
            )
            st.code(str(PENDING_DATA_PATH), language=None)
            st.info(
                "Model đang phục vụ chưa thay đổi. Bước tiếp theo là kiểm duyệt nguồn, nạp dữ liệu vào PostgreSQL, "
                "chạy lại Notebook 05 và 06, rồi chỉ phát hành model mới nếu kết quả validation/test tốt hơn."
            )

st.caption(
    "Trang này phục vụ cập nhật tập dữ liệu huấn luyện. Trang Prediction vẫn là nơi người dùng cuối nhận dự đoán."
)
