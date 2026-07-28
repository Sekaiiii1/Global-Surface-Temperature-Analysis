-- =============================================================================
-- 05_indexes.sql
-- Tạo indexes, cập nhật planner statistics, chạy final audit
-- và xác nhận nguồn dữ liệu bàn giao cho Notebook 03.
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

ANALYZE staging_global;
ANALYZE staging_country;
ANALYZE staging_city;
ANALYZE staging_major_city;
ANALYZE fact_global_temperature;
ANALYZE fact_country_temperature;
ANALYZE fact_city_temperature;
ANALYZE fact_major_city_temperature;
ANALYZE dim_date;
ANALYZE dim_country;
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


-- =============================================================================
-- Final audit: chỉ READY khi toàn bộ data contract của pipeline đều đạt.
-- =============================================================================

WITH object_inventory(object_group, expected_count, found_count) AS (
    SELECT
        'staging_tables',
        4::BIGINT,
        COUNT(*)::BIGINT
    FROM information_schema.tables
    WHERE table_schema = 'public'
      AND table_type = 'BASE TABLE'
      AND table_name IN (
          'staging_global',
          'staging_country',
          'staging_city',
          'staging_major_city'
      )

    UNION ALL

    SELECT
        'dimension_tables',
        3,
        COUNT(*)
    FROM information_schema.tables
    WHERE table_schema = 'public'
      AND table_type = 'BASE TABLE'
      AND table_name IN ('dim_date', 'dim_country', 'dim_city')

    UNION ALL

    SELECT
        'fact_tables',
        4,
        COUNT(*)
    FROM information_schema.tables
    WHERE table_schema = 'public'
      AND table_type = 'BASE TABLE'
      AND table_name IN (
          'fact_global_temperature',
          'fact_country_temperature',
          'fact_city_temperature',
          'fact_major_city_temperature'
      )

    UNION ALL

    SELECT
        'unified_view',
        1,
        COUNT(*)
    FROM information_schema.views
    WHERE table_schema = 'public'
      AND table_name = 'vw_city_temperature_enriched'

    UNION ALL

    SELECT
        'materialized_views',
        5,
        COUNT(*)
    FROM pg_matviews
    WHERE schemaname = 'public'
      AND matviewname IN (
          'mv_global_temperature_yearly',
          'mv_global_temperature_decadal',
          'mv_country_temperature_yearly',
          'mv_city_temperature_yearly',
          'mv_major_city_temperature_yearly'
      )

    UNION ALL

    SELECT
        'pipeline_indexes',
        10,
        COUNT(*)
    FROM pg_indexes
    WHERE schemaname = 'public'
      AND indexname IN (
          'idx_staging_country_country_dt',
          'idx_fact_country_temperature_country_date',
          'idx_fact_city_temperature_city_date',
          'idx_fact_major_city_temperature_city_date',
          'idx_dim_city_country_major',
          'ux_mv_global_temperature_yearly_year',
          'ux_mv_global_temperature_decadal_decade',
          'ux_mv_country_temperature_yearly_grain',
          'ux_mv_city_temperature_yearly_grain',
          'ux_mv_major_city_temperature_yearly_grain'
      )
),
fact_counts(dataset, expected_rows, actual_rows) AS (
    VALUES
        (
            'global',
            3192::BIGINT,
            (SELECT COUNT(*) FROM fact_global_temperature)
        ),
        (
            'country',
            577462::BIGINT,
            (SELECT COUNT(*) FROM fact_country_temperature)
        ),
        (
            'city',
            5637812::BIGINT,
            (SELECT COUNT(*) FROM fact_city_temperature)
        ),
        (
            'major_city',
            239177::BIGINT,
            (SELECT COUNT(*) FROM fact_major_city_temperature)
        )
),
staging_city_contract AS (
    SELECT
        COUNT(*) = 5637812
        AND COUNT(DISTINCT BTRIM(country)) = 50
        AND COUNT(DISTINCT dt) = 1809
        AND MIN(dt) = DATE '1863-01-01'
        AND MAX(dt) = DATE '2013-09-01'
        AND COUNT(*) FILTER (
            WHERE average_temperature IS NULL
        ) = 58727
        AND COUNT(*) FILTER (
            WHERE dt < DATE '1863-01-01'
               OR dt >= DATE '2014-01-01'
               OR dt IS NULL
        ) = 0 AS value
    FROM staging_city
),
view_audit AS (
    SELECT
        COUNT(*)::BIGINT AS actual_rows,
        COUNT(*) FILTER (
            WHERE NOT country_matched
        )::BIGINT AS country_unmatched_rows,
        COUNT(*) FILTER (
            WHERE NOT global_matched
        )::BIGINT AS global_unmatched_rows,
        COUNT(*) FILTER (
            WHERE NOT major_city_matched
              AND is_major_city IS TRUE
        )::BIGINT AS unexpected_major_city_unmatched_rows
    FROM vw_city_temperature_enriched
),
aggregation_validation AS (
    SELECT
        COUNT(*) > 0
        AND COUNT(*) = COUNT(DISTINCT year)
        AND COUNT(*) FILTER (
            WHERE year IS NULL
               OR observation_months <= 0
               OR valid_temperature_months + missing_temperature_months
                  <> observation_months
        ) = 0 AS value
    FROM mv_global_temperature_yearly

    UNION ALL

    SELECT
        COUNT(*) > 0
        AND COUNT(*) = COUNT(DISTINCT decade)
        AND COUNT(*) FILTER (
            WHERE decade IS NULL
               OR observation_months <= 0
               OR valid_temperature_months + missing_temperature_months
                  <> observation_months
        ) = 0
    FROM mv_global_temperature_decadal

    UNION ALL

    SELECT
        COUNT(*) > 0
        AND COUNT(*) = COUNT(DISTINCT (country_id, year))
        AND COUNT(*) FILTER (
            WHERE country_id IS NULL
               OR year IS NULL
               OR observation_months <= 0
               OR valid_temperature_months + missing_temperature_months
                  <> observation_months
        ) = 0
    FROM mv_country_temperature_yearly

    UNION ALL

    SELECT
        COUNT(*) > 0
        AND COUNT(*) = COUNT(DISTINCT (city_id, year))
        AND COUNT(*) FILTER (
            WHERE city_id IS NULL
               OR year IS NULL
               OR observation_months <= 0
               OR valid_temperature_months + missing_temperature_months
                  <> observation_months
        ) = 0
    FROM mv_city_temperature_yearly

    UNION ALL

    SELECT
        COUNT(*) > 0
        AND COUNT(*) = COUNT(DISTINCT (city_id, year))
        AND COUNT(*) FILTER (
            WHERE city_id IS NULL
               OR year IS NULL
               OR observation_months <= 0
               OR valid_temperature_months + missing_temperature_months
                  <> observation_months
        ) = 0
    FROM mv_major_city_temperature_yearly
),
checks(check_name, passed) AS (
    SELECT
        'database_objects',
        BOOL_AND(expected_count = found_count)
    FROM object_inventory

    UNION ALL

    SELECT
        'fact_row_counts',
        BOOL_AND(expected_rows = actual_rows)
    FROM fact_counts

    UNION ALL

    SELECT
        'staging_city_contract',
        value
    FROM staging_city_contract

    UNION ALL

    SELECT
        'unified_view_and_enrichment',
        actual_rows = 5637812
        -- Top-50 quốc gia được chọn từ cùng bảng City nên mọi dòng đều ghép được Country.
        AND country_unmatched_rows = 0
        AND global_unmatched_rows = 0
        AND unexpected_major_city_unmatched_rows = 0
    FROM view_audit

    UNION ALL

    SELECT
        'aggregations',
        BOOL_AND(value)
    FROM aggregation_validation
)
SELECT
    check_name,
    passed,
    CASE WHEN passed THEN 'PASS' ELSE 'FAIL' END AS status,
    CASE
        WHEN BOOL_AND(passed) OVER ()
        THEN 'POSTGRESQL PIPELINE: READY'
        ELSE 'POSTGRESQL PIPELINE: NOT READY'
    END AS pipeline_status
FROM checks
ORDER BY check_name;


-- =============================================================================
-- Bàn giao nguồn dữ liệu cho Notebook 03.
-- =============================================================================

SELECT
    'city_enriched' AS dataset,
    'vw_city_temperature_enriched' AS source_view,
    (SELECT COUNT(*) FROM fact_city_temperature) AS expected_rows,
    COUNT(*) AS actual_rows,
    COUNT(*) - (SELECT COUNT(*) FROM fact_city_temperature) AS difference,
    'observation_date + country_name + city_name + latitude + longitude'
        AS lineage_columns,
    CASE
        WHEN COUNT(*) = (SELECT COUNT(*) FROM fact_city_temperature)
        THEN 'PASS'
        ELSE 'FAIL'
    END AS status
FROM vw_city_temperature_enriched;

SELECT *
FROM vw_city_temperature_enriched
ORDER BY country_name, city_name, observation_date
LIMIT 10;
