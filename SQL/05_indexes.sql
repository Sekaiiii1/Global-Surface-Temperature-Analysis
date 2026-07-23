-- =============================================================================
-- 05_indexes.sql
-- Tạo index, cập nhật statistics, kiểm tra execution plan và final audit.
-- Chạy cuối cùng, sau khi bulk load và materialized aggregation đã hoàn tất.
-- Primary key và UNIQUE constraint từ 01_create_tables.sql không được lặp lại.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. Index cho staging/fact, dimension và materialized views.
-- -----------------------------------------------------------------------------

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

-- -----------------------------------------------------------------------------
-- 2. Cập nhật statistics để query planner chọn execution plan phù hợp.
-- ANALYZE không thay đổi dữ liệu trong bảng.
-- -----------------------------------------------------------------------------

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

-- -----------------------------------------------------------------------------
-- 3. Xác nhận đủ 13 index do pipeline chủ động tạo.
-- -----------------------------------------------------------------------------

WITH expected_indexes(indexname) AS (
    VALUES
        ('idx_staging_country_country_dt'),
        ('idx_fact_country_temperature_country_date'),
        ('idx_fact_state_temperature_state_date'),
        ('idx_fact_city_temperature_city_date'),
        ('idx_fact_major_city_temperature_city_date'),
        ('idx_dim_state_country'),
        ('idx_dim_city_country_major'),
        ('ux_mv_global_temperature_yearly_year'),
        ('ux_mv_global_temperature_decadal_decade'),
        ('ux_mv_country_temperature_yearly_grain'),
        ('ux_mv_state_temperature_yearly_grain'),
        ('ux_mv_city_temperature_yearly_grain'),
        ('ux_mv_major_city_temperature_yearly_grain')
)
SELECT
    e.indexname,
    p.tablename,
    p.indexdef,
    CASE
        WHEN p.indexname IS NOT NULL THEN 'PASS'
        ELSE 'FAIL'
    END AS status
FROM expected_indexes AS e
LEFT JOIN pg_indexes AS p
  ON p.schemaname = 'public'
 AND p.indexname = e.indexname
ORDER BY e.indexname;

-- -----------------------------------------------------------------------------
-- 4. Kiểm tra execution plan của truy vấn Country và City.
-- -----------------------------------------------------------------------------

EXPLAIN (ANALYZE, BUFFERS)
SELECT
    date_id,
    average_temperature
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
SELECT
    date_id,
    average_temperature
FROM fact_city_temperature
WHERE city_id = (
    SELECT city_id
    FROM fact_city_temperature
    GROUP BY city_id
    ORDER BY COUNT(*) DESC, city_id
    LIMIT 1
)
ORDER BY date_id;

-- -----------------------------------------------------------------------------
-- 5. Final audit: kiểm kê object và xác nhận data contract bàn giao Notebook 03.
-- -----------------------------------------------------------------------------

-- Kiểm kê các nhóm object chính.
WITH object_inventory(object_group, expected_count, found_count) AS (
    SELECT
        'staging_tables',
        5::BIGINT,
        COUNT(*)::BIGINT
    FROM information_schema.tables
    WHERE table_schema = 'public'
      AND table_type = 'BASE TABLE'
      AND table_name IN (
          'staging_global',
          'staging_country',
          'staging_state',
          'staging_city',
          'staging_major_city'
      )

    UNION ALL

    SELECT
        'dimension_tables',
        4,
        COUNT(*)
    FROM information_schema.tables
    WHERE table_schema = 'public'
      AND table_type = 'BASE TABLE'
      AND table_name IN (
          'dim_date',
          'dim_country',
          'dim_state',
          'dim_city'
      )

    UNION ALL

    SELECT
        'fact_tables',
        5,
        COUNT(*)
    FROM information_schema.tables
    WHERE table_schema = 'public'
      AND table_type = 'BASE TABLE'
      AND table_name IN (
          'fact_global_temperature',
          'fact_country_temperature',
          'fact_state_temperature',
          'fact_city_temperature',
          'fact_major_city_temperature'
      )

    UNION ALL

    SELECT
        'monthly_views',
        5,
        COUNT(*)
    FROM information_schema.views
    WHERE table_schema = 'public'
      AND table_name IN (
          'vw_global_temperature',
          'vw_country_temperature',
          'vw_state_temperature',
          'vw_city_temperature',
          'vw_major_city_temperature'
      )

    UNION ALL

    SELECT
        'materialized_views',
        6,
        COUNT(*)
    FROM pg_matviews
    WHERE schemaname = 'public'
      AND matviewname IN (
          'mv_global_temperature_yearly',
          'mv_global_temperature_decadal',
          'mv_country_temperature_yearly',
          'mv_state_temperature_yearly',
          'mv_city_temperature_yearly',
          'mv_major_city_temperature_yearly'
      )

    UNION ALL

    SELECT
        'pipeline_indexes',
        13,
        COUNT(*)
    FROM pg_indexes
    WHERE schemaname = 'public'
      AND indexname IN (
          'idx_staging_country_country_dt',
          'idx_fact_country_temperature_country_date',
          'idx_fact_state_temperature_state_date',
          'idx_fact_city_temperature_city_date',
          'idx_fact_major_city_temperature_city_date',
          'idx_dim_state_country',
          'idx_dim_city_country_major',
          'ux_mv_global_temperature_yearly_year',
          'ux_mv_global_temperature_decadal_decade',
          'ux_mv_country_temperature_yearly_grain',
          'ux_mv_state_temperature_yearly_grain',
          'ux_mv_city_temperature_yearly_grain',
          'ux_mv_major_city_temperature_yearly_grain'
      )
)
SELECT
    object_group,
    expected_count,
    found_count,
    CASE
        WHEN expected_count = found_count THEN 'PASS'
        ELSE 'FAIL'
    END AS status
FROM object_inventory
ORDER BY object_group;

-- Data contract bàn giao cho Notebook 03.
WITH handoff(dataset, source_view, expected_rows, actual_rows) AS (
    SELECT
        'global',
        'vw_global_temperature',
        3192::BIGINT,
        COUNT(*)::BIGINT
    FROM vw_global_temperature
    UNION ALL
    SELECT
        'country',
        'vw_country_temperature',
        577462,
        COUNT(*)
    FROM vw_country_temperature
    UNION ALL
    SELECT
        'state',
        'vw_state_temperature',
        645675,
        COUNT(*)
    FROM vw_state_temperature
    UNION ALL
    SELECT
        'city',
        'vw_city_temperature',
        5010113,
        COUNT(*)
    FROM vw_city_temperature
    UNION ALL
    SELECT
        'major_city',
        'vw_major_city_temperature',
        239177,
        COUNT(*)
    FROM vw_major_city_temperature
)
SELECT
    dataset,
    source_view,
    expected_rows,
    actual_rows,
    actual_rows - expected_rows AS difference,
    'source_staging_id' AS lineage_column,
    CASE
        WHEN expected_rows = actual_rows THEN 'PASS'
        ELSE 'FAIL'
    END AS status
FROM handoff
ORDER BY dataset;

-- Chỉ READY khi mọi monthly view bảo toàn đúng row count.
SELECT
    CASE
        WHEN (SELECT COUNT(*) FROM vw_global_temperature) = 3192
         AND (SELECT COUNT(*) FROM vw_country_temperature) = 577462
         AND (SELECT COUNT(*) FROM vw_state_temperature) = 645675
         AND (SELECT COUNT(*) FROM vw_city_temperature) = 5010113
         AND (SELECT COUNT(*) FROM vw_major_city_temperature) = 239177
        THEN 'POSTGRESQL PIPELINE: READY'
        ELSE 'POSTGRESQL PIPELINE: NOT READY'
    END AS pipeline_status;

-- -----------------------------------------------------------------------------
-- 6. Các truy vấn mẫu dành cho người thực hiện Notebook 03 sau khi restore.
-- -----------------------------------------------------------------------------

-- Các câu lệnh nguồn để người làm Notebook 03 kiểm tra sau restore.
SELECT COUNT(*) AS global_rows
FROM vw_global_temperature;

SELECT COUNT(*) AS country_rows
FROM vw_country_temperature;

SELECT COUNT(*) AS state_rows
FROM vw_state_temperature;

SELECT COUNT(*) AS city_rows
FROM vw_city_temperature;

SELECT COUNT(*) AS major_city_rows
FROM vw_major_city_temperature;

-- Mẫu dữ liệu bàn giao từ các monthly analytical views.
SELECT *
FROM vw_global_temperature
ORDER BY global_temperature_id
LIMIT 10;

SELECT *
FROM vw_country_temperature
ORDER BY country_temperature_id
LIMIT 10;

SELECT *
FROM vw_state_temperature
ORDER BY state_temperature_id
LIMIT 10;

SELECT *
FROM vw_city_temperature
ORDER BY city_temperature_id
LIMIT 10;

SELECT *
FROM vw_major_city_temperature
ORDER BY major_city_temperature_id
LIMIT 10;
