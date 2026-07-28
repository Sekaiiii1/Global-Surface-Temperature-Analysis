-- =============================================================================
-- 03_views.sql
-- Tạo monthly views, view hợp nhất và kiểm tra chất lượng join.
-- Chạy sau 02_import_data.sql.
-- =============================================================================

BEGIN;

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

-- View hợp nhất: City là grain gốc, các nguồn còn lại LEFT JOIN tối đa một dòng.
CREATE OR REPLACE VIEW vw_city_temperature_enriched AS
SELECT
    ci.city_temperature_id,
    ci.source_staging_id,
    d.date_id,
    d.full_date AS observation_date,
    d.year,
    d.month,
    d.quarter,
    d.decade,
    city.city_id,
    city.city_name,
    country.country_id,
    country.country_name,
    city.latitude,
    city.longitude,
    city.is_major_city,
    ci.average_temperature AS city_average_temperature,
    ci.average_temperature_uncertainty AS city_average_temperature_uncertainty,
    co.country_temperature_id AS country_match_id,
    co.average_temperature AS country_average_temperature,
    co.average_temperature_uncertainty AS country_average_temperature_uncertainty,
    g.global_temperature_id AS global_match_id,
    g.land_average_temperature,
    g.land_average_temperature_uncertainty,
    g.land_max_temperature,
    g.land_max_temperature_uncertainty,
    g.land_min_temperature,
    g.land_min_temperature_uncertainty,
    g.land_and_ocean_average_temperature,
    g.land_and_ocean_average_temperature_uncertainty,
    mc.major_city_temperature_id AS major_city_match_id,
    mc.average_temperature AS major_city_average_temperature,
    mc.average_temperature_uncertainty AS major_city_average_temperature_uncertainty
FROM fact_city_temperature AS ci
JOIN dim_date AS d ON d.date_id = ci.date_id
JOIN dim_city AS city ON city.city_id = ci.city_id
JOIN dim_country AS country ON country.country_id = city.country_id
LEFT JOIN fact_country_temperature AS co
       ON co.date_id = ci.date_id
      AND co.country_id = city.country_id
LEFT JOIN fact_global_temperature AS g
       ON g.date_id = ci.date_id
LEFT JOIN fact_major_city_temperature AS mc
       ON mc.date_id = ci.date_id
      AND mc.city_id = ci.city_id;

COMMENT ON VIEW vw_global_temperature IS
    'Global temperature facts enriched with calendar attributes';
COMMENT ON VIEW vw_country_temperature IS
    'Country temperature facts enriched with calendar and country attributes';
COMMENT ON VIEW vw_city_temperature IS
    'City temperature facts enriched with calendar and geographic attributes';
COMMENT ON VIEW vw_major_city_temperature IS
    'Major-city temperature facts enriched with calendar and geographic attributes';
COMMENT ON VIEW vw_city_temperature_enriched IS
    'City-grain view enriched with Country, Global and Major City values';

COMMIT;

-- Kiểm tra view hợp nhất không làm mất hoặc nhân bản dòng.
SELECT
    (SELECT COUNT(*) FROM vw_city_temperature_enriched) AS view_row_count,
    (SELECT COUNT(*) FROM fact_city_temperature) AS fact_city_row_count,
    (SELECT COUNT(*) FROM vw_city_temperature_enriched)
        - (SELECT COUNT(*) FROM fact_city_temperature) AS difference,
    CASE
        WHEN (SELECT COUNT(*) FROM vw_city_temperature_enriched)
           = (SELECT COUNT(*) FROM fact_city_temperature)
        THEN 'PASS'
        ELSE 'FAIL'
    END AS status;

-- Đo match rate bằng một lần quét view và phân biệt missing có chủ đích với lỗi join.
WITH raw_country_keys AS (
    SELECT DISTINCT dt, BTRIM(country) AS country
    FROM staging_country
    WHERE dt IS NOT NULL
      AND NULLIF(BTRIM(country), '') IS NOT NULL
),
raw_global_dates AS (
    SELECT DISTINCT dt
    FROM staging_global
    WHERE dt IS NOT NULL
),
metrics AS MATERIALIZED (
    SELECT
        COUNT(*)::BIGINT AS source_rows,
        COUNT(v.country_match_id)::BIGINT AS country_matched_rows,
        COUNT(*) FILTER (
            WHERE v.country_match_id IS NULL
        )::BIGINT AS country_unmatched_rows,
        COUNT(*) FILTER (
            WHERE v.country_match_id IS NULL
              AND country_key.dt IS NULL
        )::BIGINT AS country_expected_unmatched,
        COUNT(*) FILTER (
            WHERE v.country_match_id IS NULL
              AND country_key.dt IS NOT NULL
        )::BIGINT AS country_unexpected_unmatched,
        COUNT(*) FILTER (
            WHERE v.country_match_id IS NOT NULL
              AND v.country_average_temperature IS NULL
        )::BIGINT AS country_source_temperature_nulls,
        COUNT(v.global_match_id)::BIGINT AS global_matched_rows,
        COUNT(*) FILTER (
            WHERE v.global_match_id IS NULL
        )::BIGINT AS global_unmatched_rows,
        COUNT(*) FILTER (
            WHERE v.global_match_id IS NULL
              AND global_date.dt IS NULL
        )::BIGINT AS global_expected_unmatched,
        COUNT(*) FILTER (
            WHERE v.global_match_id IS NULL
              AND global_date.dt IS NOT NULL
        )::BIGINT AS global_unexpected_unmatched,
        COUNT(*) FILTER (
            WHERE v.global_match_id IS NOT NULL
              AND v.land_average_temperature IS NULL
        )::BIGINT AS global_source_temperature_nulls,
        COUNT(v.major_city_match_id)::BIGINT AS major_city_matched_rows,
        COUNT(*) FILTER (
            WHERE v.major_city_match_id IS NULL
        )::BIGINT AS major_city_unmatched_rows,
        COUNT(*) FILTER (
            WHERE v.major_city_match_id IS NULL
              AND v.is_major_city IS FALSE
        )::BIGINT AS major_city_expected_unmatched,
        COUNT(*) FILTER (
            WHERE v.major_city_match_id IS NULL
              AND v.is_major_city IS TRUE
        )::BIGINT AS major_city_unexpected_unmatched,
        COUNT(*) FILTER (
            WHERE v.major_city_match_id IS NOT NULL
              AND v.major_city_average_temperature IS NULL
        )::BIGINT AS major_city_source_temperature_nulls
    FROM vw_city_temperature_enriched AS v
    LEFT JOIN raw_country_keys AS country_key
      ON country_key.dt = v.observation_date
     AND country_key.country = v.country_name
    LEFT JOIN raw_global_dates AS global_date
      ON global_date.dt = v.observation_date
),
validation AS (
    SELECT
        'city_to_country'::TEXT AS enrichment,
        source_rows,
        country_matched_rows AS matched_rows,
        country_unmatched_rows AS unmatched_rows,
        country_expected_unmatched AS expected_unmatched,
        country_unexpected_unmatched AS unexpected_unmatched,
        country_source_temperature_nulls AS source_temperature_nulls
    FROM metrics

    UNION ALL

    SELECT
        'city_to_global',
        source_rows,
        global_matched_rows,
        global_unmatched_rows,
        global_expected_unmatched,
        global_unexpected_unmatched,
        global_source_temperature_nulls
    FROM metrics

    UNION ALL

    SELECT
        'city_to_major_city',
        source_rows,
        major_city_matched_rows,
        major_city_unmatched_rows,
        major_city_expected_unmatched,
        major_city_unexpected_unmatched,
        major_city_source_temperature_nulls
    FROM metrics
)
SELECT
    val.*,
    (SELECT COUNT(*) FROM fact_city_temperature) AS fact_city_rows,
    ROUND(
        100.0 * val.matched_rows / NULLIF(val.source_rows, 0),
        4
    ) AS match_rate_percent,
    CASE
        WHEN val.source_rows = (SELECT COUNT(*) FROM fact_city_temperature)
         AND val.unexpected_unmatched = 0
        THEN 'PASS'
        ELSE 'FAIL'
    END AS status
FROM validation AS val
ORDER BY val.enrichment;

-- Mẫu dữ liệu tích hợp dùng để kiểm tra trực quan.
SELECT
    observation_date,
    city_name,
    country_name,
    city_average_temperature,
    country_average_temperature,
    land_average_temperature,
    major_city_average_temperature,
    is_major_city
FROM vw_city_temperature_enriched
ORDER BY city_temperature_id
LIMIT 10;
