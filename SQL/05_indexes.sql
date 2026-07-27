-- =============================================================================
-- 05_indexes.sql
-- Indexes hỗ trợ join, lọc và truy vấn lịch sử của pipeline 4 bảng.
-- =============================================================================

CREATE INDEX IF NOT EXISTS idx_staging_country_country_dt
    ON staging_country (country, dt);

CREATE INDEX IF NOT EXISTS idx_fact_country_temperature_country_date
    ON fact_country_temperature (country_id, date_id);

CREATE INDEX IF NOT EXISTS idx_fact_city_temperature_city_date
    ON fact_city_temperature (city_id, date_id);

CREATE INDEX IF NOT EXISTS idx_fact_major_city_temperature_city_date
    ON fact_major_city_temperature (city_id, date_id);

CREATE INDEX IF NOT EXISTS idx_dim_city_country_major
    ON dim_city (country_id, is_major_city);

CREATE UNIQUE INDEX IF NOT EXISTS ux_mv_global_temperature_yearly_year
    ON mv_global_temperature_yearly (year);

CREATE UNIQUE INDEX IF NOT EXISTS ux_mv_global_temperature_decadal_decade
    ON mv_global_temperature_decadal (decade);

CREATE UNIQUE INDEX IF NOT EXISTS ux_mv_country_temperature_yearly_grain
    ON mv_country_temperature_yearly (country_id, year);

CREATE UNIQUE INDEX IF NOT EXISTS ux_mv_city_temperature_yearly_grain
    ON mv_city_temperature_yearly (city_id, year);

CREATE UNIQUE INDEX IF NOT EXISTS ux_mv_major_city_temperature_yearly_grain
    ON mv_major_city_temperature_yearly (city_id, year);

ANALYZE staging_country;
ANALYZE fact_country_temperature;
ANALYZE fact_city_temperature;
ANALYZE fact_major_city_temperature;
ANALYZE dim_city;
ANALYZE mv_global_temperature_yearly;
ANALYZE mv_global_temperature_decadal;
ANALYZE mv_country_temperature_yearly;
ANALYZE mv_city_temperature_yearly;
ANALYZE mv_major_city_temperature_yearly;

WITH expected_indexes(indexname) AS (
    VALUES
        ('idx_staging_country_country_dt'),
        ('idx_fact_country_temperature_country_date'),
        ('idx_fact_city_temperature_city_date'),
        ('idx_fact_major_city_temperature_city_date'),
        ('idx_dim_city_country_major'),
        ('ux_mv_global_temperature_yearly_year'),
        ('ux_mv_global_temperature_decadal_decade'),
        ('ux_mv_country_temperature_yearly_grain'),
        ('ux_mv_city_temperature_yearly_grain'),
        ('ux_mv_major_city_temperature_yearly_grain')
)
SELECT
    e.indexname,
    p.tablename,
    p.indexdef,
    CASE WHEN p.indexname IS NOT NULL THEN 'PASS' ELSE 'FAIL' END AS status
FROM expected_indexes AS e
LEFT JOIN pg_indexes AS p
  ON p.schemaname = 'public'
 AND p.indexname = e.indexname
ORDER BY e.indexname;

-- Query plan mẫu; EXPLAIN ANALYZE xác nhận index ở phần truy vấn ngoài.
EXPLAIN (ANALYZE, BUFFERS)
SELECT date_id, average_temperature
FROM fact_country_temperature
WHERE country_id = (
    SELECT country_id
    FROM fact_country_temperature
    GROUP BY country_id
    ORDER BY COUNT(*) DESC, country_id
    LIMIT 1
)
ORDER BY date_id;
EXPLAIN (ANALYZE, BUFFERS)
SELECT date_id, average_temperature
FROM fact_city_temperature
WHERE city_id = (
    SELECT city_id
    FROM fact_city_temperature
    GROUP BY city_id
    ORDER BY COUNT(*) DESC, city_id
    LIMIT 1
)
ORDER BY date_id;
