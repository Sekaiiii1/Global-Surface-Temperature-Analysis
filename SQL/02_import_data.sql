-- =============================================================================
-- 02_import_data.sql
-- COPY templates used by notebooks/02_postgresql_pipeline.ipynb.
--
-- These statements use COPY ... FROM STDIN. They require a client such as
-- psycopg2 to open each local CSV and stream its contents to PostgreSQL.
-- Do not execute this entire file directly without providing STDIN data.
-- Empty, unquoted CSV fields are imported as SQL NULL values.
-- =============================================================================

-- GlobalTemperatures.csv
TRUNCATE TABLE staging_global RESTART IDENTITY;
COPY staging_global (
    dt,
    land_average_temperature,
    land_average_temperature_uncertainty,
    land_max_temperature,
    land_max_temperature_uncertainty,
    land_min_temperature,
    land_min_temperature_uncertainty,
    land_and_ocean_average_temperature,
    land_and_ocean_average_temperature_uncertainty
)
FROM STDIN
WITH (FORMAT CSV, HEADER TRUE, DELIMITER ',', QUOTE '"', ESCAPE '"', NULL '');

-- GlobalLandTemperaturesByCountry.csv
TRUNCATE TABLE staging_country RESTART IDENTITY;
COPY staging_country (
    dt,
    average_temperature,
    average_temperature_uncertainty,
    country
)
FROM STDIN
WITH (FORMAT CSV, HEADER TRUE, DELIMITER ',', QUOTE '"', ESCAPE '"', NULL '');

-- GlobalLandTemperaturesByState.csv
TRUNCATE TABLE staging_state RESTART IDENTITY;
COPY staging_state (
    dt,
    average_temperature,
    average_temperature_uncertainty,
    state,
    country
)
FROM STDIN
WITH (FORMAT CSV, HEADER TRUE, DELIMITER ',', QUOTE '"', ESCAPE '"', NULL '');

-- GlobalLandTemperaturesByCity.csv
TRUNCATE TABLE staging_city RESTART IDENTITY;
COPY staging_city (
    dt,
    average_temperature,
    average_temperature_uncertainty,
    city,
    country,
    latitude,
    longitude
)
FROM STDIN
WITH (FORMAT CSV, HEADER TRUE, DELIMITER ',', QUOTE '"', ESCAPE '"', NULL '');

-- GlobalLandTemperaturesByMajorCity.csv
TRUNCATE TABLE staging_major_city RESTART IDENTITY;
COPY staging_major_city (
    dt,
    average_temperature,
    average_temperature_uncertainty,
    city,
    country,
    latitude,
    longitude
)
FROM STDIN
WITH (FORMAT CSV, HEADER TRUE, DELIMITER ',', QUOTE '"', ESCAPE '"', NULL '');
