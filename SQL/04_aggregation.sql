-- =============================================================================
-- 04_aggregation.sql
-- Tạo năm materialized views tổng hợp từ monthly analytical views.
-- Có DROP trước mỗi lần tạo để script chạy lại trên cùng database.
-- =============================================================================

BEGIN;

DROP MATERIALIZED VIEW IF EXISTS mv_global_temperature_yearly;
DROP MATERIALIZED VIEW IF EXISTS mv_global_temperature_decadal;
DROP MATERIALIZED VIEW IF EXISTS mv_country_temperature_yearly;
DROP MATERIALIZED VIEW IF EXISTS mv_city_temperature_yearly;
DROP MATERIALIZED VIEW IF EXISTS mv_major_city_temperature_yearly;

CREATE MATERIALIZED VIEW mv_global_temperature_yearly AS
SELECT
    year,
    COUNT(*)::BIGINT AS observation_months,
    COUNT(land_average_temperature)::BIGINT AS valid_temperature_months,
    COUNT(*) FILTER (WHERE land_average_temperature IS NULL)::BIGINT
        AS missing_temperature_months,
    AVG(land_average_temperature) AS average_land_temperature,
    MIN(land_average_temperature) AS minimum_land_temperature,
    MAX(land_average_temperature) AS maximum_land_temperature,
    AVG(land_average_temperature_uncertainty) AS average_land_uncertainty,
    AVG(land_and_ocean_average_temperature) AS average_land_ocean_temperature,
    AVG(land_and_ocean_average_temperature_uncertainty)
        AS average_land_ocean_uncertainty
FROM vw_global_temperature
GROUP BY year;

CREATE MATERIALIZED VIEW mv_global_temperature_decadal AS
SELECT
    decade,
    MIN(year)::SMALLINT AS first_year,
    MAX(year)::SMALLINT AS last_year,
    COUNT(*)::BIGINT AS observation_months,
    COUNT(land_average_temperature)::BIGINT AS valid_temperature_months,
    COUNT(*) FILTER (WHERE land_average_temperature IS NULL)::BIGINT
        AS missing_temperature_months,
    AVG(land_average_temperature) AS average_land_temperature,
    MIN(land_average_temperature) AS minimum_land_temperature,
    MAX(land_average_temperature) AS maximum_land_temperature,
    AVG(land_average_temperature_uncertainty) AS average_land_uncertainty,
    AVG(land_and_ocean_average_temperature) AS average_land_ocean_temperature,
    AVG(land_and_ocean_average_temperature_uncertainty)
        AS average_land_ocean_uncertainty
FROM vw_global_temperature
GROUP BY decade;

CREATE MATERIALIZED VIEW mv_country_temperature_yearly AS
SELECT
    country_id,
    country_name,
    year,
    COUNT(*)::BIGINT AS observation_months,
    COUNT(average_temperature)::BIGINT AS valid_temperature_months,
    COUNT(*) FILTER (WHERE average_temperature IS NULL)::BIGINT
        AS missing_temperature_months,
    AVG(average_temperature) AS average_temperature,
    MIN(average_temperature) AS minimum_temperature,
    MAX(average_temperature) AS maximum_temperature,
    AVG(average_temperature_uncertainty) AS average_temperature_uncertainty
FROM vw_country_temperature
GROUP BY country_id, country_name, year;

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
    COUNT(*) FILTER (WHERE average_temperature IS NULL)::BIGINT
        AS missing_temperature_months,
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
    COUNT(*) FILTER (WHERE average_temperature IS NULL)::BIGINT
        AS missing_temperature_months,
    AVG(average_temperature) AS average_temperature,
    MIN(average_temperature) AS minimum_temperature,
    MAX(average_temperature) AS maximum_temperature,
    AVG(average_temperature_uncertainty) AS average_temperature_uncertainty
FROM vw_major_city_temperature
GROUP BY
    city_id, city_name, country_id, country_name,
    latitude, longitude, is_major_city, year;

COMMIT;

-- Kiểm tra grain và coverage của năm materialized views.
WITH validation AS (
    SELECT
        'mv_global_temperature_yearly'::TEXT AS materialized_view,
        COUNT(*)::BIGINT AS row_count,
        COUNT(*) - COUNT(DISTINCT year) AS duplicate_grain_rows,
        COUNT(*) FILTER (WHERE year IS NULL) AS null_grain_rows,
        COUNT(*) FILTER (
            WHERE observation_months <= 0
               OR valid_temperature_months + missing_temperature_months
                  <> observation_months
        ) AS invalid_coverage_rows
    FROM mv_global_temperature_yearly
    UNION ALL
    SELECT
        'mv_global_temperature_decadal',
        COUNT(*),
        COUNT(*) - COUNT(DISTINCT decade),
        COUNT(*) FILTER (WHERE decade IS NULL),
        COUNT(*) FILTER (
            WHERE observation_months <= 0
               OR valid_temperature_months + missing_temperature_months
                  <> observation_months
        )
    FROM mv_global_temperature_decadal
    UNION ALL
    SELECT
        'mv_country_temperature_yearly',
        COUNT(*),
        COUNT(*) - COUNT(DISTINCT (country_id, year)),
        COUNT(*) FILTER (WHERE country_id IS NULL OR year IS NULL),
        COUNT(*) FILTER (
            WHERE observation_months <= 0
               OR valid_temperature_months + missing_temperature_months
                  <> observation_months
        )
    FROM mv_country_temperature_yearly
    UNION ALL
    SELECT
        'mv_city_temperature_yearly',
        COUNT(*),
        COUNT(*) - COUNT(DISTINCT (city_id, year)),
        COUNT(*) FILTER (WHERE city_id IS NULL OR year IS NULL),
        COUNT(*) FILTER (
            WHERE observation_months <= 0
               OR valid_temperature_months + missing_temperature_months
                  <> observation_months
        )
    FROM mv_city_temperature_yearly
    UNION ALL
    SELECT
        'mv_major_city_temperature_yearly',
        COUNT(*),
        COUNT(*) - COUNT(DISTINCT (city_id, year)),
        COUNT(*) FILTER (WHERE city_id IS NULL OR year IS NULL),
        COUNT(*) FILTER (
            WHERE observation_months <= 0
               OR valid_temperature_months + missing_temperature_months
                  <> observation_months
        )
    FROM mv_major_city_temperature_yearly
)
SELECT *,
    CASE
        WHEN row_count > 0
         AND duplicate_grain_rows = 0
         AND null_grain_rows = 0
         AND invalid_coverage_rows = 0
        THEN 'PASS'
        ELSE 'FAIL'
    END AS status
FROM validation
ORDER BY materialized_view;
