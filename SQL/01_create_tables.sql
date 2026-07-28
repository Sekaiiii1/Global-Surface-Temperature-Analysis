-- =============================================================================
-- 01_create_tables.sql
-- Tạo staging, dimension và fact tables cho pipeline 4 nguồn.
-- Chạy trên database climate_db mới, trước 02_import_data.sql.
-- =============================================================================

-- Dừng sớm nếu Query Tool đang kết nối nhầm database.
DO $$
BEGIN
    IF current_database() <> 'climate_db' THEN
        RAISE EXCEPTION
            'Đang kết nối database %, cần chuyển sang climate_db.',
            current_database();
    END IF;
END
$$;

SET search_path TO public;

BEGIN;

-- 1. Staging layer: giữ gần với cấu trúc CSV nguồn.
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

CREATE TABLE staging_country (
    staging_id BIGSERIAL PRIMARY KEY,
    dt DATE,
    average_temperature DOUBLE PRECISION,
    average_temperature_uncertainty DOUBLE PRECISION,
    country TEXT,
    loaded_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

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

COMMENT ON TABLE staging_global IS
    'Raw monthly global data from GlobalTemperatures.csv';
COMMENT ON TABLE staging_country IS
    'Raw monthly country data from GlobalLandTemperaturesByCountry.csv';
COMMENT ON TABLE staging_city IS
    'Raw monthly city data from GlobalLandTemperaturesByCity.csv';
COMMENT ON TABLE staging_major_city IS
    'Raw monthly major-city data from GlobalLandTemperaturesByMajorCity.csv';

-- 2. Dimension layer.
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

-- 3. Fact layer. source_staging_id bảo toàn data lineage.
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

COMMENT ON TABLE dim_date IS 'Calendar dimension shared by temperature facts';
COMMENT ON TABLE dim_country IS 'Normalized country names from geographic datasets';
COMMENT ON TABLE dim_city IS 'Normalized city-country-coordinate combinations';
COMMENT ON TABLE fact_global_temperature IS 'Monthly global temperature observations';
COMMENT ON TABLE fact_country_temperature IS 'Monthly country temperature observations';
COMMENT ON TABLE fact_city_temperature IS 'Monthly city temperature observations';
COMMENT ON TABLE fact_major_city_temperature IS 'Monthly major-city temperature observations';

COMMIT;

-- Kiểm tra đúng 4 staging tables được tạo.
SELECT 'staging_global' AS table_name, COUNT(*) AS row_count
FROM staging_global
UNION ALL
SELECT 'staging_country', COUNT(*) FROM staging_country
UNION ALL
SELECT 'staging_city', COUNT(*) FROM staging_city
UNION ALL
SELECT 'staging_major_city', COUNT(*) FROM staging_major_city
ORDER BY table_name;
