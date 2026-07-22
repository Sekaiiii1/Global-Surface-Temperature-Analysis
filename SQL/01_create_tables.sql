-- =============================================================================
-- 01_create_tables.sql
-- Recreate the PostgreSQL staging and analytical layers.
-- WARNING: DROP TABLE ... CASCADE removes existing data and dependants.
-- This script is executed inside a transaction controlled by Notebook 02.
-- =============================================================================

DROP TABLE IF EXISTS staging_major_city CASCADE;
DROP TABLE IF EXISTS staging_city CASCADE;
DROP TABLE IF EXISTS staging_state CASCADE;
DROP TABLE IF EXISTS staging_country CASCADE;
DROP TABLE IF EXISTS staging_global CASCADE;

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

CREATE TABLE staging_state (
    staging_id BIGSERIAL PRIMARY KEY,
    dt DATE,
    average_temperature DOUBLE PRECISION,
    average_temperature_uncertainty DOUBLE PRECISION,
    state TEXT,
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
    'Raw monthly global temperature data imported from GlobalTemperatures.csv';
COMMENT ON TABLE staging_country IS
    'Raw monthly country temperature data imported from GlobalLandTemperaturesByCountry.csv';
COMMENT ON TABLE staging_state IS
    'Raw monthly state temperature data imported from GlobalLandTemperaturesByState.csv';
COMMENT ON TABLE staging_city IS
    'Raw monthly city temperature data imported from GlobalLandTemperaturesByCity.csv';
COMMENT ON TABLE staging_major_city IS
    'Raw monthly major-city temperature data imported from GlobalLandTemperaturesByMajorCity.csv';

-- BEGIN ANALYTICAL_SCHEMA
-- This marked block can be executed independently by Notebook 02 after staging
-- has been imported and validated.

DROP TABLE IF EXISTS fact_major_city_temperature CASCADE;
DROP TABLE IF EXISTS fact_city_temperature CASCADE;
DROP TABLE IF EXISTS fact_state_temperature CASCADE;
DROP TABLE IF EXISTS fact_country_temperature CASCADE;
DROP TABLE IF EXISTS fact_global_temperature CASCADE;
DROP TABLE IF EXISTS dim_city CASCADE;
DROP TABLE IF EXISTS dim_state CASCADE;
DROP TABLE IF EXISTS dim_country CASCADE;
DROP TABLE IF EXISTS dim_date CASCADE;

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

COMMENT ON TABLE dim_date IS 'Calendar dimension shared by all temperature facts';
COMMENT ON TABLE dim_country IS 'Normalized country names from all geographic datasets';
COMMENT ON TABLE dim_state IS 'Normalized state-country combinations';
COMMENT ON TABLE dim_city IS 'Normalized city-country-coordinate combinations';
COMMENT ON TABLE fact_global_temperature IS 'Monthly global temperature observations';
COMMENT ON TABLE fact_country_temperature IS 'Monthly country temperature observations';
COMMENT ON TABLE fact_state_temperature IS 'Monthly state temperature observations';
COMMENT ON TABLE fact_city_temperature IS 'Monthly city temperature observations';
COMMENT ON TABLE fact_major_city_temperature IS 'Monthly major-city temperature observations';

-- END ANALYTICAL_SCHEMA
