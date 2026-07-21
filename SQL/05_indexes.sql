-- =============================================================================
-- 05_indexes.sql
-- Add non-duplicative lookup indexes after bulk loading and aggregation.
-- Primary-key and UNIQUE indexes already created by 01_create_tables.sql are
-- intentionally not repeated here.
-- =============================================================================

CREATE INDEX IF NOT EXISTS idx_staging_country_country_dt
    ON staging_country (country, dt);

CREATE INDEX IF NOT EXISTS idx_fact_country_temperature_country_date
    ON fact_country_temperature (country_id, date_id);

CREATE INDEX IF NOT EXISTS idx_fact_state_temperature_state_date
    ON fact_state_temperature (state_id, date_id);

CREATE INDEX IF NOT EXISTS idx_fact_city_temperature_city_date
    ON fact_city_temperature (city_id, date_id);

CREATE INDEX IF NOT EXISTS idx_fact_major_city_temperature_city_date
    ON fact_major_city_temperature (city_id, date_id);

CREATE INDEX IF NOT EXISTS idx_dim_state_country
    ON dim_state (country_id);

CREATE INDEX IF NOT EXISTS idx_dim_city_country_major
    ON dim_city (country_id, is_major_city);

CREATE UNIQUE INDEX IF NOT EXISTS ux_mv_global_temperature_yearly_year
    ON mv_global_temperature_yearly (year);

CREATE UNIQUE INDEX IF NOT EXISTS ux_mv_global_temperature_decadal_decade
    ON mv_global_temperature_decadal (decade);

CREATE UNIQUE INDEX IF NOT EXISTS ux_mv_country_temperature_yearly_grain
    ON mv_country_temperature_yearly (country_id, year);

CREATE UNIQUE INDEX IF NOT EXISTS ux_mv_state_temperature_yearly_grain
    ON mv_state_temperature_yearly (state_id, year);

CREATE UNIQUE INDEX IF NOT EXISTS ux_mv_city_temperature_yearly_grain
    ON mv_city_temperature_yearly (city_id, year);

CREATE UNIQUE INDEX IF NOT EXISTS ux_mv_major_city_temperature_yearly_grain
    ON mv_major_city_temperature_yearly (city_id, year);

ANALYZE staging_country;
ANALYZE fact_country_temperature;
ANALYZE fact_state_temperature;
ANALYZE fact_city_temperature;
ANALYZE fact_major_city_temperature;
ANALYZE dim_state;
ANALYZE dim_city;
ANALYZE mv_global_temperature_yearly;
ANALYZE mv_global_temperature_decadal;
ANALYZE mv_country_temperature_yearly;
ANALYZE mv_state_temperature_yearly;
ANALYZE mv_city_temperature_yearly;
ANALYZE mv_major_city_temperature_yearly;
