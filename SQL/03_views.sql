-- =============================================================================
-- 03_views.sql
-- Tạo các monthly analytical views và xác minh các phép join.
-- Chạy sau khi 02_import_data.sql đã nạp đủ dimension và fact.
-- CREATE OR REPLACE VIEW cho phép cập nhật định nghĩa view mà không xóa dữ liệu.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. Tạo năm view theo cấp độ Global, Country, State, City và Major City.
-- -----------------------------------------------------------------------------

CREATE OR REPLACE VIEW vw_global_temperature AS
SELECT
    f.global_temperature_id,
    f.source_staging_id,
    d.date_id,
    d.full_date AS observation_date,
    d.year,
    d.month,
    d.quarter,
    d.decade,
    f.land_average_temperature,
    f.land_average_temperature_uncertainty,
    f.land_max_temperature,
    f.land_max_temperature_uncertainty,
    f.land_min_temperature,
    f.land_min_temperature_uncertainty,
    f.land_and_ocean_average_temperature,
    f.land_and_ocean_average_temperature_uncertainty
FROM fact_global_temperature AS f
JOIN dim_date AS d ON d.date_id = f.date_id;

CREATE OR REPLACE VIEW vw_country_temperature AS
SELECT
    f.country_temperature_id,
    f.source_staging_id,
    d.date_id,
    d.full_date AS observation_date,
    d.year,
    d.month,
    d.quarter,
    d.decade,
    c.country_id,
    c.country_name,
    f.average_temperature,
    f.average_temperature_uncertainty
FROM fact_country_temperature AS f
JOIN dim_date AS d ON d.date_id = f.date_id
JOIN dim_country AS c ON c.country_id = f.country_id;

CREATE OR REPLACE VIEW vw_state_temperature AS
SELECT
    f.state_temperature_id,
    f.source_staging_id,
    d.date_id,
    d.full_date AS observation_date,
    d.year,
    d.month,
    d.quarter,
    d.decade,
    s.state_id,
    s.state_name,
    c.country_id,
    c.country_name,
    f.average_temperature,
    f.average_temperature_uncertainty
FROM fact_state_temperature AS f
JOIN dim_date AS d ON d.date_id = f.date_id
JOIN dim_state AS s ON s.state_id = f.state_id
JOIN dim_country AS c ON c.country_id = s.country_id;

CREATE OR REPLACE VIEW vw_city_temperature AS
SELECT
    f.city_temperature_id,
    f.source_staging_id,
    d.date_id,
    d.full_date AS observation_date,
    d.year,
    d.month,
    d.quarter,
    d.decade,
    ci.city_id,
    ci.city_name,
    c.country_id,
    c.country_name,
    ci.latitude,
    ci.longitude,
    ci.is_major_city,
    f.average_temperature,
    f.average_temperature_uncertainty
FROM fact_city_temperature AS f
JOIN dim_date AS d ON d.date_id = f.date_id
JOIN dim_city AS ci ON ci.city_id = f.city_id
JOIN dim_country AS c ON c.country_id = ci.country_id;

CREATE OR REPLACE VIEW vw_major_city_temperature AS
SELECT
    f.major_city_temperature_id,
    f.source_staging_id,
    d.date_id,
    d.full_date AS observation_date,
    d.year,
    d.month,
    d.quarter,
    d.decade,
    ci.city_id,
    ci.city_name,
    c.country_id,
    c.country_name,
    ci.latitude,
    ci.longitude,
    ci.is_major_city,
    f.average_temperature,
    f.average_temperature_uncertainty
FROM fact_major_city_temperature AS f
JOIN dim_date AS d ON d.date_id = f.date_id
JOIN dim_city AS ci ON ci.city_id = f.city_id
JOIN dim_country AS c ON c.country_id = ci.country_id;

COMMENT ON VIEW vw_global_temperature IS 'Global temperature facts enriched with calendar attributes';
COMMENT ON VIEW vw_country_temperature IS 'Country temperature facts enriched with calendar and country attributes';
COMMENT ON VIEW vw_state_temperature IS 'State temperature facts enriched with calendar, state and country attributes';
COMMENT ON VIEW vw_city_temperature IS 'City temperature facts enriched with calendar and geographic attributes';
COMMENT ON VIEW vw_major_city_temperature IS 'Major-city temperature facts enriched with calendar and geographic attributes';

-- -----------------------------------------------------------------------------
-- 2. Kiểm tra row count và xem mẫu dữ liệu sau enrichment.
-- -----------------------------------------------------------------------------

-- Row count của views phải khớp row count fact/source.
SELECT 'vw_global_temperature' AS view_name, COUNT(*) AS row_count
FROM vw_global_temperature
UNION ALL
SELECT 'vw_country_temperature', COUNT(*) FROM vw_country_temperature
UNION ALL
SELECT 'vw_state_temperature', COUNT(*) FROM vw_state_temperature
UNION ALL
SELECT 'vw_city_temperature', COUNT(*) FROM vw_city_temperature
UNION ALL
SELECT 'vw_major_city_temperature', COUNT(*) FROM vw_major_city_temperature
ORDER BY view_name;

-- Kiểm tra nhanh cấu trúc và dữ liệu mẫu.
SELECT *
FROM vw_country_temperature
ORDER BY country_temperature_id
LIMIT 5;

SELECT *
FROM vw_city_temperature
ORDER BY city_temperature_id
LIMIT 5;

-- -----------------------------------------------------------------------------
-- 3. Kiểm tra bốn phép join: không nhân dòng và không unmatched ngoài dự kiến.
-- -----------------------------------------------------------------------------

WITH
global_range AS (
    SELECT
        MIN(observation_date) AS min_date,
        MAX(observation_date) AS max_date
    FROM vw_global_temperature
),
raw_country_keys AS (
    SELECT DISTINCT dt, country
    FROM staging_country
),
country_joined AS (
    SELECT
        c.country_temperature_id AS source_id,
        c.observation_date,
        g.global_temperature_id AS target_id,
        r.min_date,
        r.max_date
    FROM vw_country_temperature AS c
    CROSS JOIN global_range AS r
    LEFT JOIN vw_global_temperature AS g
      ON g.date_id = c.date_id
),
state_joined AS (
    SELECT
        s.state_temperature_id AS source_id,
        c.country_temperature_id AS target_id,
        raw.country AS raw_country_key
    FROM vw_state_temperature AS s
    LEFT JOIN vw_country_temperature AS c
      ON c.date_id = s.date_id
     AND c.country_id = s.country_id
    LEFT JOIN raw_country_keys AS raw
      ON raw.dt = s.observation_date
     AND raw.country = s.country_name
),
city_joined AS (
    SELECT
        ci.city_temperature_id AS source_id,
        c.country_temperature_id AS target_id,
        raw.country AS raw_country_key
    FROM vw_city_temperature AS ci
    LEFT JOIN vw_country_temperature AS c
      ON c.date_id = ci.date_id
     AND c.country_id = ci.country_id
    LEFT JOIN raw_country_keys AS raw
      ON raw.dt = ci.observation_date
     AND raw.country = ci.country_name
),
major_city_joined AS (
    SELECT
        ci.major_city_temperature_id AS source_id,
        c.country_temperature_id AS target_id,
        raw.country AS raw_country_key
    FROM vw_major_city_temperature AS ci
    LEFT JOIN vw_country_temperature AS c
      ON c.date_id = ci.date_id
     AND c.country_id = ci.country_id
    LEFT JOIN raw_country_keys AS raw
      ON raw.dt = ci.observation_date
     AND raw.country = ci.country_name
),
validation AS (
    SELECT
        'country_to_global'::TEXT AS join_name,
        COUNT(*)::BIGINT AS source_rows,
        COUNT(*)::BIGINT AS joined_rows,
        COUNT(target_id)::BIGINT AS matched_rows,
        COUNT(*) FILTER (WHERE target_id IS NULL)::BIGINT AS unmatched_rows,
        COUNT(*) FILTER (
            WHERE target_id IS NULL
              AND observation_date NOT BETWEEN min_date AND max_date
        )::BIGINT AS expected_unmatched,
        COUNT(*) FILTER (
            WHERE target_id IS NULL
              AND observation_date BETWEEN min_date AND max_date
        )::BIGINT AS unexpected_unmatched,
        COUNT(*) - COUNT(DISTINCT source_id) AS row_multiplication
    FROM country_joined

    UNION ALL

    SELECT
        'state_to_country',
        COUNT(*),
        COUNT(*),
        COUNT(target_id),
        COUNT(*) FILTER (WHERE target_id IS NULL),
        COUNT(*) FILTER (
            WHERE target_id IS NULL AND raw_country_key IS NULL
        ),
        COUNT(*) FILTER (
            WHERE target_id IS NULL AND raw_country_key IS NOT NULL
        ),
        COUNT(*) - COUNT(DISTINCT source_id)
    FROM state_joined

    UNION ALL

    SELECT
        'city_to_country',
        COUNT(*),
        COUNT(*),
        COUNT(target_id),
        COUNT(*) FILTER (WHERE target_id IS NULL),
        COUNT(*) FILTER (
            WHERE target_id IS NULL AND raw_country_key IS NULL
        ),
        COUNT(*) FILTER (
            WHERE target_id IS NULL AND raw_country_key IS NOT NULL
        ),
        COUNT(*) - COUNT(DISTINCT source_id)
    FROM city_joined

    UNION ALL

    SELECT
        'major_city_to_country',
        COUNT(*),
        COUNT(*),
        COUNT(target_id),
        COUNT(*) FILTER (WHERE target_id IS NULL),
        COUNT(*) FILTER (
            WHERE target_id IS NULL AND raw_country_key IS NULL
        ),
        COUNT(*) FILTER (
            WHERE target_id IS NULL AND raw_country_key IS NOT NULL
        ),
        COUNT(*) - COUNT(DISTINCT source_id)
    FROM major_city_joined
)
SELECT
    *,
    ROUND(
        100.0 * matched_rows / NULLIF(source_rows, 0),
        4
    ) AS match_rate_percent,
    CASE
        WHEN row_multiplication = 0
         AND unexpected_unmatched = 0
        THEN 'PASS'
        ELSE 'FAIL'
    END AS status
FROM validation
ORDER BY join_name;

-- -----------------------------------------------------------------------------
-- 4. Mẫu join City -> Country -> Global.
-- -----------------------------------------------------------------------------

-- Minh họa enrichment City → Country → Global.
SELECT
    ci.observation_date,
    ci.city_name,
    ci.country_name,
    ci.average_temperature AS city_temperature,
    c.average_temperature AS country_temperature,
    g.land_average_temperature AS global_land_temperature
FROM vw_city_temperature AS ci
LEFT JOIN vw_country_temperature AS c
  ON c.date_id = ci.date_id
 AND c.country_id = ci.country_id
LEFT JOIN vw_global_temperature AS g
  ON g.date_id = ci.date_id
ORDER BY ci.city_temperature_id
LIMIT 10;
