-- =============================================================================
-- 03_views.sql
-- Reusable analytical views over the normalized dimension and fact tables.
-- Views retain rows with NULL temperature values and expose source_staging_id
-- for lineage back to the staging layer.
-- =============================================================================

DROP VIEW IF EXISTS vw_major_city_temperature CASCADE;
DROP VIEW IF EXISTS vw_city_temperature CASCADE;
DROP VIEW IF EXISTS vw_state_temperature CASCADE;
DROP VIEW IF EXISTS vw_country_temperature CASCADE;
DROP VIEW IF EXISTS vw_global_temperature CASCADE;

CREATE VIEW vw_global_temperature AS
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

CREATE VIEW vw_country_temperature AS
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

CREATE VIEW vw_state_temperature AS
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

CREATE VIEW vw_city_temperature AS
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

CREATE VIEW vw_major_city_temperature AS
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
