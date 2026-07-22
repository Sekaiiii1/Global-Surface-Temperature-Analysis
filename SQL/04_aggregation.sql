-- =============================================================================
-- 04_aggregation.sql
-- Rebuild reusable materialized aggregations from the analytical views.
-- AVG ignores NULL temperatures; explicit coverage columns preserve visibility
-- into the number of valid and missing monthly observations in every group.
-- =============================================================================

DROP MATERIALIZED VIEW IF EXISTS mv_major_city_temperature_yearly CASCADE;
DROP MATERIALIZED VIEW IF EXISTS mv_city_temperature_yearly CASCADE;
DROP MATERIALIZED VIEW IF EXISTS mv_state_temperature_yearly CASCADE;
DROP MATERIALIZED VIEW IF EXISTS mv_country_temperature_yearly CASCADE;
DROP MATERIALIZED VIEW IF EXISTS mv_global_temperature_decadal CASCADE;
DROP MATERIALIZED VIEW IF EXISTS mv_global_temperature_yearly CASCADE;

CREATE MATERIALIZED VIEW mv_global_temperature_yearly AS
SELECT
    year,
    COUNT(*)::BIGINT AS observation_months,
    COUNT(land_average_temperature)::BIGINT AS valid_temperature_months,
    COUNT(*) FILTER (
        WHERE land_average_temperature IS NULL
    )::BIGINT AS missing_temperature_months,
    AVG(land_average_temperature) AS average_land_temperature,
    MIN(land_average_temperature) AS minimum_land_temperature,
    MAX(land_average_temperature) AS maximum_land_temperature,
    AVG(land_average_temperature_uncertainty) AS average_land_uncertainty,
    AVG(land_and_ocean_average_temperature) AS average_land_ocean_temperature,
    AVG(
        land_and_ocean_average_temperature_uncertainty
    ) AS average_land_ocean_uncertainty
FROM vw_global_temperature
GROUP BY year;

CREATE MATERIALIZED VIEW mv_global_temperature_decadal AS
SELECT
    decade,
    MIN(year)::SMALLINT AS first_year,
    MAX(year)::SMALLINT AS last_year,
    COUNT(*)::BIGINT AS observation_months,
    COUNT(land_average_temperature)::BIGINT AS valid_temperature_months,
    COUNT(*) FILTER (
        WHERE land_average_temperature IS NULL
    )::BIGINT AS missing_temperature_months,
    AVG(land_average_temperature) AS average_land_temperature,
    MIN(land_average_temperature) AS minimum_land_temperature,
    MAX(land_average_temperature) AS maximum_land_temperature,
    AVG(land_average_temperature_uncertainty) AS average_land_uncertainty,
    AVG(land_and_ocean_average_temperature) AS average_land_ocean_temperature,
    AVG(
        land_and_ocean_average_temperature_uncertainty
    ) AS average_land_ocean_uncertainty
FROM vw_global_temperature
GROUP BY decade;

CREATE MATERIALIZED VIEW mv_country_temperature_yearly AS
SELECT
    country_id,
    country_name,
    year,
    COUNT(*)::BIGINT AS observation_months,
    COUNT(average_temperature)::BIGINT AS valid_temperature_months,
    COUNT(*) FILTER (
        WHERE average_temperature IS NULL
    )::BIGINT AS missing_temperature_months,
    AVG(average_temperature) AS average_temperature,
    MIN(average_temperature) AS minimum_temperature,
    MAX(average_temperature) AS maximum_temperature,
    AVG(average_temperature_uncertainty) AS average_temperature_uncertainty
FROM vw_country_temperature
GROUP BY country_id, country_name, year;

CREATE MATERIALIZED VIEW mv_state_temperature_yearly AS
SELECT
    state_id,
    state_name,
    country_id,
    country_name,
    year,
    COUNT(*)::BIGINT AS observation_months,
    COUNT(average_temperature)::BIGINT AS valid_temperature_months,
    COUNT(*) FILTER (
        WHERE average_temperature IS NULL
    )::BIGINT AS missing_temperature_months,
    AVG(average_temperature) AS average_temperature,
    MIN(average_temperature) AS minimum_temperature,
    MAX(average_temperature) AS maximum_temperature,
    AVG(average_temperature_uncertainty) AS average_temperature_uncertainty
FROM vw_state_temperature
GROUP BY state_id, state_name, country_id, country_name, year;

CREATE MATERIALIZED VIEW mv_city_temperature_yearly AS
SELECT
    city_id,
    city_name,
    country_id,
    country_name,
    latitude,
    longitude,
    is_major_city,
    year,
    COUNT(*)::BIGINT AS observation_months,
    COUNT(average_temperature)::BIGINT AS valid_temperature_months,
    COUNT(*) FILTER (
        WHERE average_temperature IS NULL
    )::BIGINT AS missing_temperature_months,
    AVG(average_temperature) AS average_temperature,
    MIN(average_temperature) AS minimum_temperature,
    MAX(average_temperature) AS maximum_temperature,
    AVG(average_temperature_uncertainty) AS average_temperature_uncertainty
FROM vw_city_temperature
GROUP BY
    city_id, city_name, country_id, country_name,
    latitude, longitude, is_major_city, year;

CREATE MATERIALIZED VIEW mv_major_city_temperature_yearly AS
SELECT
    city_id,
    city_name,
    country_id,
    country_name,
    latitude,
    longitude,
    is_major_city,
    year,
    COUNT(*)::BIGINT AS observation_months,
    COUNT(average_temperature)::BIGINT AS valid_temperature_months,
    COUNT(*) FILTER (
        WHERE average_temperature IS NULL
    )::BIGINT AS missing_temperature_months,
    AVG(average_temperature) AS average_temperature,
    MIN(average_temperature) AS minimum_temperature,
    MAX(average_temperature) AS maximum_temperature,
    AVG(average_temperature_uncertainty) AS average_temperature_uncertainty
FROM vw_major_city_temperature
GROUP BY
    city_id, city_name, country_id, country_name,
    latitude, longitude, is_major_city, year;

COMMENT ON MATERIALIZED VIEW mv_global_temperature_yearly IS
    'Annual global temperature aggregation with monthly coverage metrics';
COMMENT ON MATERIALIZED VIEW mv_global_temperature_decadal IS
    'Decadal global temperature aggregation with monthly coverage metrics';
COMMENT ON MATERIALIZED VIEW mv_country_temperature_yearly IS
    'Annual country temperature aggregation with monthly coverage metrics';
COMMENT ON MATERIALIZED VIEW mv_state_temperature_yearly IS
    'Annual state temperature aggregation with monthly coverage metrics';
COMMENT ON MATERIALIZED VIEW mv_city_temperature_yearly IS
    'Annual city temperature aggregation with monthly coverage metrics';
COMMENT ON MATERIALIZED VIEW mv_major_city_temperature_yearly IS
    'Annual major-city temperature aggregation with monthly coverage metrics';
