-- =============================================================================
-- 01_create_tables.sql
-- Tạo mới toàn bộ cấu trúc staging và mô hình phân tích.
-- Chạy một lần trên database climate_db mới, trước 02_import_data.sql.
-- Script không DROP object cũ; nếu bảng đã tồn tại, PostgreSQL sẽ báo lỗi để
-- tránh vô tình xóa dữ liệu.
-- =============================================================================

BEGIN;

-- -----------------------------------------------------------------------------
-- 1. Staging tables: phản ánh cấu trúc của năm tệp CSV nguồn.
-- -----------------------------------------------------------------------------

CREATE TABLE staging_global (
    staging_id BIGSERIAL PRIMARY KEY,
    dt DATE,
    land_average_temperature DOUBLE PRECISION,
    land_average_temperature_uncertainty DOUBLE PRECISION,
    land_max_temperature DOUBLE PRECISION,
    land_max_temperature_uncertainty DOUBLE PRECISION,
    land_min_temperature DOUBLE PRECISION,
    land_min_temperature_uncertainty DOUBLE PRECISION,
    land_and_ocean_average_temperature DOUBLE PRECISION,
    land_and_ocean_average_temperature_uncertainty DOUBLE PRECISION,
    loaded_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

COMMENT ON TABLE staging_global IS
    'Raw monthly global data from GlobalTemperatures.csv';

CREATE TABLE staging_country (
    staging_id BIGSERIAL PRIMARY KEY,
    dt DATE,
    average_temperature DOUBLE PRECISION,
    average_temperature_uncertainty DOUBLE PRECISION,
    country TEXT,
    loaded_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

COMMENT ON TABLE staging_country IS
    'Raw monthly country data from GlobalLandTemperaturesByCountry.csv';

CREATE TABLE staging_state (
    staging_id BIGSERIAL PRIMARY KEY,
    dt DATE,
    average_temperature DOUBLE PRECISION,
    average_temperature_uncertainty DOUBLE PRECISION,
    state TEXT,
    country TEXT,
    loaded_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

COMMENT ON TABLE staging_state IS
    'Raw monthly state data from GlobalLandTemperaturesByState.csv';

CREATE TABLE staging_city (
    staging_id BIGSERIAL PRIMARY KEY,
    dt DATE,
    average_temperature DOUBLE PRECISION,
    average_temperature_uncertainty DOUBLE PRECISION,
    city TEXT,
    country TEXT,
    latitude TEXT,
    longitude TEXT,
    loaded_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

COMMENT ON TABLE staging_city IS
    'Raw monthly city data from GlobalLandTemperaturesByCity.csv';

CREATE TABLE staging_major_city (
    staging_id BIGSERIAL PRIMARY KEY,
    dt DATE,
    average_temperature DOUBLE PRECISION,
    average_temperature_uncertainty DOUBLE PRECISION,
    city TEXT,
    country TEXT,
    latitude TEXT,
    longitude TEXT,
    loaded_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

COMMENT ON TABLE staging_major_city IS
    'Raw monthly major-city data from GlobalLandTemperaturesByMajorCity.csv';

-- -----------------------------------------------------------------------------
-- 2. Dimension tables: chuẩn hóa thời gian và thực thể địa lý.
-- -----------------------------------------------------------------------------

CREATE TABLE dim_date (
    date_id BIGSERIAL PRIMARY KEY,
    full_date DATE NOT NULL UNIQUE,
    year SMALLINT NOT NULL,
    month SMALLINT NOT NULL CHECK (month BETWEEN 1 AND 12),
    quarter SMALLINT NOT NULL CHECK (quarter BETWEEN 1 AND 4),
    decade SMALLINT NOT NULL
);

CREATE TABLE dim_country (
    country_id BIGSERIAL PRIMARY KEY,
    country_name TEXT NOT NULL UNIQUE,
    CHECK (BTRIM(country_name) <> '')
);

CREATE TABLE dim_state (
    state_id BIGSERIAL PRIMARY KEY,
    state_name TEXT NOT NULL,
    country_id BIGINT NOT NULL REFERENCES dim_country(country_id),
    UNIQUE (state_name, country_id),
    CHECK (BTRIM(state_name) <> '')
);

CREATE TABLE dim_city (
    city_id BIGSERIAL PRIMARY KEY,
    city_name TEXT NOT NULL,
    country_id BIGINT NOT NULL REFERENCES dim_country(country_id),
    latitude DOUBLE PRECISION NOT NULL CHECK (latitude BETWEEN -90 AND 90),
    longitude DOUBLE PRECISION NOT NULL CHECK (longitude BETWEEN -180 AND 180),
    is_major_city BOOLEAN NOT NULL DEFAULT FALSE,
    UNIQUE (city_name, country_id, latitude, longitude),
    CHECK (BTRIM(city_name) <> '')
);

-- -----------------------------------------------------------------------------
-- 3. Fact tables: lưu các quan sát nhiệt độ theo grain tháng.
-- source_staging_id duy trì lineage về đúng dòng dữ liệu staging.
-- -----------------------------------------------------------------------------

CREATE TABLE fact_global_temperature (
    global_temperature_id BIGSERIAL PRIMARY KEY,
    date_id BIGINT NOT NULL REFERENCES dim_date(date_id),
    source_staging_id BIGINT NOT NULL UNIQUE,
    land_average_temperature DOUBLE PRECISION,
    land_average_temperature_uncertainty DOUBLE PRECISION,
    land_max_temperature DOUBLE PRECISION,
    land_max_temperature_uncertainty DOUBLE PRECISION,
    land_min_temperature DOUBLE PRECISION,
    land_min_temperature_uncertainty DOUBLE PRECISION,
    land_and_ocean_average_temperature DOUBLE PRECISION,
    land_and_ocean_average_temperature_uncertainty DOUBLE PRECISION,
    UNIQUE (date_id)
);

CREATE TABLE fact_country_temperature (
    country_temperature_id BIGSERIAL PRIMARY KEY,
    date_id BIGINT NOT NULL REFERENCES dim_date(date_id),
    country_id BIGINT NOT NULL REFERENCES dim_country(country_id),
    source_staging_id BIGINT NOT NULL UNIQUE,
    average_temperature DOUBLE PRECISION,
    average_temperature_uncertainty DOUBLE PRECISION,
    UNIQUE (date_id, country_id)
);

CREATE TABLE fact_state_temperature (
    state_temperature_id BIGSERIAL PRIMARY KEY,
    date_id BIGINT NOT NULL REFERENCES dim_date(date_id),
    state_id BIGINT NOT NULL REFERENCES dim_state(state_id),
    source_staging_id BIGINT NOT NULL UNIQUE,
    average_temperature DOUBLE PRECISION,
    average_temperature_uncertainty DOUBLE PRECISION,
    UNIQUE (date_id, state_id)
);

CREATE TABLE fact_city_temperature (
    city_temperature_id BIGSERIAL PRIMARY KEY,
    date_id BIGINT NOT NULL REFERENCES dim_date(date_id),
    city_id BIGINT NOT NULL REFERENCES dim_city(city_id),
    source_staging_id BIGINT NOT NULL UNIQUE,
    average_temperature DOUBLE PRECISION,
    average_temperature_uncertainty DOUBLE PRECISION,
    UNIQUE (date_id, city_id)
);

CREATE TABLE fact_major_city_temperature (
    major_city_temperature_id BIGSERIAL PRIMARY KEY,
    date_id BIGINT NOT NULL REFERENCES dim_date(date_id),
    city_id BIGINT NOT NULL REFERENCES dim_city(city_id),
    source_staging_id BIGINT NOT NULL UNIQUE,
    average_temperature DOUBLE PRECISION,
    average_temperature_uncertainty DOUBLE PRECISION,
    UNIQUE (date_id, city_id)
);

COMMENT ON TABLE dim_date IS
    'Calendar dimension shared by all temperature facts';
COMMENT ON TABLE dim_country IS
    'Normalized country names from all geographic datasets';
COMMENT ON TABLE dim_state IS
    'Normalized state-country combinations';
COMMENT ON TABLE dim_city IS
    'Normalized city-country-coordinate combinations';
COMMENT ON TABLE fact_global_temperature IS
    'Monthly global temperature observations';
COMMENT ON TABLE fact_country_temperature IS
    'Monthly country temperature observations';
COMMENT ON TABLE fact_state_temperature IS
    'Monthly state temperature observations';
COMMENT ON TABLE fact_city_temperature IS
    'Monthly city temperature observations';
COMMENT ON TABLE fact_major_city_temperature IS
    'Monthly major-city temperature observations';

COMMIT;

-- Xác nhận năm staging tables đã được tạo và đang rỗng.
-- Phải trả về đúng 5 bảng, mỗi bảng có row_count = 0.
SELECT 'staging_global' AS table_name, COUNT(*) AS row_count
FROM staging_global
UNION ALL
SELECT 'staging_country', COUNT(*) FROM staging_country
UNION ALL
SELECT 'staging_state', COUNT(*) FROM staging_state
UNION ALL
SELECT 'staging_city', COUNT(*) FROM staging_city
UNION ALL
SELECT 'staging_major_city', COUNT(*) FROM staging_major_city
ORDER BY table_name;
