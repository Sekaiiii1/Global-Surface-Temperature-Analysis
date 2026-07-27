-- =============================================================================
-- 03_views.sql
-- Tạo monthly views và view hợp nhất bàn giao cho Notebook 03.
-- Chạy sau 02_import_data.sql.
-- =============================================================================

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
