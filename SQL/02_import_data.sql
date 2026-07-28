-- =============================================================================
-- 02_import_data.sql
-- COPY và kiểm tra bốn CSV, cắt staging_city theo data contract,
-- sau đó nạp dimensions/facts.
-- Chạy trên database climate_db sau 01_create_tables.sql.
-- Sửa đường dẫn COPY theo máy thực thi; dữ liệu City bị cắt trực tiếp.
-- =============================================================================

-- Script này dành cho database mới. Không nối thêm dữ liệu vào staging đã có sẵn.
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM staging_global)
       OR EXISTS (SELECT 1 FROM staging_country)
       OR EXISTS (SELECT 1 FROM staging_city)
       OR EXISTS (SELECT 1 FROM staging_major_city) THEN
        RAISE EXCEPTION
            'Staging tables không rỗng. Hãy dùng database mới hoặc chủ động làm rỗng bảng trước khi import.';
    END IF;
END
$$;

BEGIN;

-- -----------------------------------------------------------------------------
-- COPY 1
-- -----------------------------------------------------------------------------

COPY staging_global (
    dt,
    land_average_temperature,
    land_average_temperature_uncertainty,
    land_max_temperature,
    land_max_temperature_uncertainty,
    land_min_temperature,
    land_min_temperature_uncertainty,
    land_and_ocean_average_temperature,
    land_and_ocean_average_temperature_uncertainty
)
FROM 'E:/FPT/HocKy3/PROJECT_1/PROJECT/Global-Surface-Temperature-Analysis/data/raw/GlobalTemperatures.csv'
WITH (
    FORMAT CSV,
    HEADER TRUE,
    DELIMITER ',',
    QUOTE '"',
    ESCAPE '"',
    NULL '',
    ENCODING 'UTF8'
);


-- -----------------------------------------------------------------------------
-- COPY 2
-- -----------------------------------------------------------------------------

COPY staging_country (
    dt,
    average_temperature,
    average_temperature_uncertainty,
    country
)
FROM 'E:/FPT/HocKy3/PROJECT_1/PROJECT/Global-Surface-Temperature-Analysis/data/raw/GlobalLandTemperaturesByCountry.csv'
WITH (
    FORMAT CSV,
    HEADER TRUE,
    DELIMITER ',',
    QUOTE '"',
    ESCAPE '"',
    NULL '',
    ENCODING 'UTF8'
);


-- -----------------------------------------------------------------------------
-- COPY 3
-- -----------------------------------------------------------------------------

COPY staging_city (
    dt,
    average_temperature,
    average_temperature_uncertainty,
    city,
    country,
    latitude,
    longitude
)
FROM 'E:/FPT/HocKy3/PROJECT_1/PROJECT/Global-Surface-Temperature-Analysis/data/raw/GlobalLandTemperaturesByCity.csv'
WITH (
    FORMAT CSV,
    HEADER TRUE,
    DELIMITER ',',
    QUOTE '"',
    ESCAPE '"',
    NULL '',
    ENCODING 'UTF8'
);


-- -----------------------------------------------------------------------------
-- COPY 4
-- -----------------------------------------------------------------------------

COPY staging_major_city (
    dt,
    average_temperature,
    average_temperature_uncertainty,
    city,
    country,
    latitude,
    longitude
)
FROM 'E:/FPT/HocKy3/PROJECT_1/PROJECT/Global-Surface-Temperature-Analysis/data/raw/GlobalLandTemperaturesByMajorCity.csv'
WITH (
    FORMAT CSV,
    HEADER TRUE,
    DELIMITER ',',
    QUOTE '"',
    ESCAPE '"',
    NULL '',
    ENCODING 'UTF8'
);

COMMIT;

-- Nếu một file hoặc một dòng CSV không hợp lệ, PostgreSQL hủy toàn bộ transaction
-- COPY ở trên; không có trạng thái chỉ import thành công một phần.
ANALYZE staging_global;
ANALYZE staging_country;
ANALYZE staging_city;
ANALYZE staging_major_city;


-- -----------------------------------------------------------------------------
-- Xác nhận import đủ dòng và metadata tự sinh
-- -----------------------------------------------------------------------------

WITH expected(dataset, expected_rows) AS (
    VALUES
        ('global', 3192::BIGINT),
        ('country', 577462::BIGINT),
        ('city', 8599212::BIGINT),
        ('major_city', 239177::BIGINT)
),
actual(dataset, actual_rows, min_staging_id, max_staging_id, null_loaded_at) AS (
    SELECT
        'global',
        COUNT(*),
        MIN(staging_id),
        MAX(staging_id),
        COUNT(*) FILTER (WHERE loaded_at IS NULL)
    FROM staging_global
    UNION ALL
    SELECT
        'country',
        COUNT(*),
        MIN(staging_id),
        MAX(staging_id),
        COUNT(*) FILTER (WHERE loaded_at IS NULL)
    FROM staging_country
    UNION ALL
    SELECT
        'city',
        COUNT(*),
        MIN(staging_id),
        MAX(staging_id),
        COUNT(*) FILTER (WHERE loaded_at IS NULL)
    FROM staging_city
    UNION ALL
    SELECT
        'major_city',
        COUNT(*),
        MIN(staging_id),
        MAX(staging_id),
        COUNT(*) FILTER (WHERE loaded_at IS NULL)
    FROM staging_major_city
)
SELECT
    e.dataset,
    e.expected_rows,
    a.actual_rows,
    a.actual_rows - e.expected_rows AS difference,
    a.min_staging_id,
    a.max_staging_id,
    a.null_loaded_at,
    CASE
        WHEN a.actual_rows = e.expected_rows
         AND a.min_staging_id = 1
         AND a.max_staging_id = a.actual_rows
         AND a.null_loaded_at = 0
        THEN 'PASS'
        ELSE 'FAIL'
    END AS status
FROM expected AS e
JOIN actual AS a USING (dataset)
ORDER BY e.dataset;


-- -----------------------------------------------------------------------------
-- Kiểm tra schema, primary key và duplicate theo grain nghiệp vụ
-- -----------------------------------------------------------------------------

SELECT
    table_name,
    ordinal_position,
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name IN (
      'staging_global',
      'staging_country',
      'staging_city',
      'staging_major_city'
  )
ORDER BY table_name, ordinal_position;

SELECT
    tc.table_name,
    tc.constraint_name,
    kcu.column_name
FROM information_schema.table_constraints AS tc
JOIN information_schema.key_column_usage AS kcu
  ON kcu.constraint_schema = tc.constraint_schema
 AND kcu.constraint_name = tc.constraint_name
WHERE tc.table_schema = 'public'
  AND tc.constraint_type = 'PRIMARY KEY'
  AND tc.table_name IN (
      'staging_global',
      'staging_country',
      'staging_city',
      'staging_major_city'
  )
ORDER BY tc.table_name;

SELECT
    'global' AS dataset,
    COUNT(*) - COUNT(DISTINCT (dt)) AS duplicate_business_keys
FROM staging_global
UNION ALL
SELECT
    'country',
    COUNT(*) - COUNT(DISTINCT (dt, country))
FROM staging_country
UNION ALL
SELECT
    'city',
    COUNT(*) - COUNT(DISTINCT (dt, city, country, latitude, longitude))
FROM staging_city
UNION ALL
SELECT
    'major_city',
    COUNT(*) - COUNT(DISTINCT (dt, city, country, latitude, longitude))
FROM staging_major_city
ORDER BY dataset;


-- -----------------------------------------------------------------------------
-- Kiểm tra dữ liệu City nguyên bản trước khi lọc theo Top-50
-- -----------------------------------------------------------------------------

WITH country_counts AS (
    SELECT
        BTRIM(country) AS country,
        COUNT(*)::BIGINT AS row_count
    FROM staging_city
    WHERE NULLIF(BTRIM(country), '') IS NOT NULL
    GROUP BY BTRIM(country)
),
ranked_countries AS (
    SELECT
        country,
        row_count,
        ROW_NUMBER() OVER (
            ORDER BY row_count DESC, country
        ) AS selection_rank
    FROM country_counts
),
source_stats AS (
    SELECT
        COUNT(*) AS source_rows,
        COUNT(*) FILTER (
            WHERE NULLIF(BTRIM(country), '') IS NULL
        ) AS invalid_country_rows
    FROM staging_city
)
SELECT
    s.source_rows,
    (SELECT COUNT(*) FROM country_counts) AS distinct_countries,
    s.invalid_country_rows,
    (SELECT COUNT(*) FROM ranked_countries WHERE selection_rank <= 50)
        AS top_50_countries,
    (SELECT COALESCE(SUM(row_count), 0)
     FROM ranked_countries
     WHERE selection_rank <= 50)
        AS top_50_rows,
    (SELECT MIN(row_count) FROM ranked_countries WHERE selection_rank <= 50)
        AS smallest_top_50_count,
    (SELECT MAX(row_count) FROM ranked_countries WHERE selection_rank <= 50)
        AS largest_top_50_count
FROM source_stats AS s;




-- -----------------------------------------------------------------------------
-- Lọc dữ liệu giữ lại 50 quốc gia có nhiều bản ghi nhất
-- -----------------------------------------------------------------------------

BEGIN;

-- Tạo lại manifest động từ số lượng bản ghi của từng quốc gia.
DROP TABLE IF EXISTS city_target_countries;

CREATE TABLE city_target_countries (
    country TEXT PRIMARY KEY,
    selection_rank INTEGER NOT NULL UNIQUE,
    selection_group TEXT NOT NULL CHECK (selection_group = 'top_50')
);

-- Xếp hạng giảm dần theo số bản ghi; tên quốc gia là tiêu chí phá hòa.
INSERT INTO city_target_countries (country, selection_rank, selection_group)
SELECT
    BTRIM(country) AS country,
    ROW_NUMBER() OVER (
        ORDER BY COUNT(*) DESC, BTRIM(country)
    )::INTEGER AS selection_rank,
    'top_50' AS selection_group
FROM staging_city
WHERE NULLIF(BTRIM(country), '') IS NOT NULL
GROUP BY BTRIM(country)
ORDER BY COUNT(*) DESC, BTRIM(country)
LIMIT 50;

-- Dừng transaction nếu manifest không đủ đúng 50 quốc gia duy nhất.
DO $$
DECLARE
    total_count INTEGER;
    distinct_rank_count INTEGER;
BEGIN
    SELECT COUNT(*), COUNT(DISTINCT selection_rank)
    INTO total_count, distinct_rank_count
    FROM city_target_countries;

    IF total_count <> 50 OR distinct_rank_count <> 50 THEN
        RAISE EXCEPTION
            'Manifest Top-50 không hợp lệ: tổng %, thứ hạng khác nhau %.',
            total_count, distinct_rank_count;
    END IF;
END
$$;

-- Xóa trực tiếp các dòng không thuộc Top-50 quốc gia.
DELETE FROM staging_city AS s
WHERE NOT EXISTS (
    SELECT 1
    FROM city_target_countries AS t
    WHERE t.country = BTRIM(s.country)
);

-- Chỉ commit nếu kết quả lọc khớp data contract đã khảo sát ở notebook 01.
DO $$
DECLARE
    remaining_rows BIGINT;
    remaining_countries INTEGER;
BEGIN
    SELECT COUNT(*), COUNT(DISTINCT BTRIM(country))
    INTO remaining_rows, remaining_countries
    FROM staging_city;

    IF remaining_rows <> 7658922
       OR remaining_countries <> 50 THEN
        RAISE EXCEPTION
            'Lọc Top-50 sai data contract: rows %, countries %.',
            remaining_rows, remaining_countries;
    END IF;
END
$$;

COMMIT;

ANALYZE staging_city;

-- Kiểm tra kết quả sau khi chỉ lọc theo Top-50 quốc gia.
SELECT
    COUNT(*) AS rows_after_country_filter,
    COUNT(DISTINCT BTRIM(country)) AS selected_countries,
    MIN(dt) AS min_date,
    MAX(dt) AS max_date,
    COUNT(*) FILTER (WHERE average_temperature IS NULL)
        AS missing_temperature_rows,
    CASE
        WHEN COUNT(*) = 7658922
         AND COUNT(DISTINCT BTRIM(country)) = 50
        THEN 'PASS'
        ELSE 'FAIL'
    END AS status
FROM staging_city;


-- -----------------------------------------------------------------------------
-- Kiểm tra dải thời gian trước khi lọc
-- -----------------------------------------------------------------------------

-- Đánh giá dải thời gian trước khi tạo bảng City cuối cùng.
SELECT
    COUNT(*) AS rows_before_time_filter,
    MIN(dt) AS min_date_before_filter,
    MAX(dt) AS max_date_before_filter,
    COUNT(DISTINCT dt) AS distinct_dates_before_filter,
    COUNT(*) FILTER (WHERE dt IS NULL) AS null_date_rows
FROM staging_city;


-- -----------------------------------------------------------------------------
-- Lọc City theo khoảng 1863-01-01 đến trước 2014-01-01
-- -----------------------------------------------------------------------------

BEGIN;

-- Xóa trực tiếp các dòng nằm ngoài giai đoạn mục tiêu.
DELETE FROM staging_city
WHERE dt < DATE '1863-01-01'
   OR dt >= DATE '2014-01-01'
   OR dt IS NULL;

-- Không cho phép commit nếu kết quả cuối sai data contract.
DO $$
DECLARE
    checked_rows BIGINT;
    checked_countries BIGINT;
    checked_dates BIGINT;
    checked_min_date DATE;
    checked_max_date DATE;
    checked_missing_temperature BIGINT;
    checked_invalid_dates BIGINT;
BEGIN
    SELECT
        COUNT(*),
        COUNT(DISTINCT BTRIM(country)),
        COUNT(DISTINCT dt),
        MIN(dt),
        MAX(dt),
        COUNT(*) FILTER (WHERE average_temperature IS NULL),
        COUNT(*) FILTER (
            WHERE dt < DATE '1863-01-01'
               OR dt >= DATE '2014-01-01'
               OR dt IS NULL
        )
    INTO
        checked_rows,
        checked_countries,
        checked_dates,
        checked_min_date,
        checked_max_date,
        checked_missing_temperature,
        checked_invalid_dates
    FROM staging_city;

    IF checked_rows <> 5637812
       OR checked_countries <> 50
       OR checked_dates <> 1809
       OR checked_min_date <> DATE '1863-01-01'
       OR checked_max_date <> DATE '2013-09-01'
       OR checked_missing_temperature <> 58727
       OR checked_invalid_dates <> 0 THEN
        RAISE EXCEPTION
            'Cắt thời gian sai data contract: rows %, countries %, dates %, min %, max %, missing %, invalid %.',
            checked_rows, checked_countries, checked_dates,
            checked_min_date, checked_max_date,
            checked_missing_temperature, checked_invalid_dates;
    END IF;
END
$$;

COMMIT;

ANALYZE staging_city;

-- Xác nhận data contract cuối của bước cắt dữ liệu.
WITH validation AS (
    SELECT
        COUNT(*) AS final_rows,
        COUNT(DISTINCT BTRIM(country)) AS final_countries,
        COUNT(DISTINCT dt) AS final_distinct_dates,
        MIN(dt) AS final_min_date,
        MAX(dt) AS final_max_date,
        COUNT(*) FILTER (WHERE average_temperature IS NULL)
            AS missing_temperature_rows,
        COUNT(*) FILTER (
            WHERE dt < DATE '1863-01-01'
               OR dt >= DATE '2014-01-01'
               OR dt IS NULL
        ) AS invalid_date_rows
    FROM staging_city
)
SELECT
    final_rows,
    final_countries,
    final_distinct_dates,
    final_min_date,
    final_max_date,
    missing_temperature_rows,
    invalid_date_rows,
    CASE
        WHEN final_rows = 5637812
         AND final_countries = 50
         AND final_distinct_dates = 1809
         AND final_min_date = DATE '1863-01-01'
         AND final_max_date = DATE '2013-09-01'
         AND missing_temperature_rows = 58727
         AND invalid_date_rows = 0
        THEN 'PASS'
        ELSE 'FAIL'
    END AS status
FROM validation;


BEGIN;

-- -----------------------------------------------------------------------------
-- Nạp dimensions
-- -----------------------------------------------------------------------------

INSERT INTO dim_date (full_date, year, month, quarter, decade)
SELECT
    full_date,
    EXTRACT(YEAR FROM full_date)::SMALLINT,
    EXTRACT(MONTH FROM full_date)::SMALLINT,
    EXTRACT(QUARTER FROM full_date)::SMALLINT,
    ((EXTRACT(YEAR FROM full_date)::INTEGER / 10) * 10)::SMALLINT
FROM (
    SELECT dt AS full_date FROM staging_global WHERE dt IS NOT NULL
    UNION
    SELECT dt FROM staging_country WHERE dt IS NOT NULL
    UNION
    SELECT dt FROM staging_city WHERE dt IS NOT NULL
    UNION
    SELECT dt FROM staging_major_city WHERE dt IS NOT NULL
) AS source_dates
ORDER BY full_date;


-- -----------------------------------------------------------------------------
-- Nạp dim_country
-- -----------------------------------------------------------------------------

INSERT INTO dim_country (country_name)
SELECT country_name
FROM (
    SELECT NULLIF(BTRIM(country), '') AS country_name FROM staging_country
    UNION
    SELECT NULLIF(BTRIM(country), '') FROM staging_city
    UNION
    SELECT NULLIF(BTRIM(country), '') FROM staging_major_city
) AS source_countries
WHERE country_name IS NOT NULL
ORDER BY country_name;


-- -----------------------------------------------------------------------------
-- Nạp dim_city và chuẩn hóa tọa độ
-- -----------------------------------------------------------------------------

WITH city_source AS (
    SELECT
        NULLIF(BTRIM(s.city), '') AS city_name,
        NULLIF(BTRIM(s.country), '') AS country_name,
        CASE
            WHEN BTRIM(s.latitude) ~ '^[0-9]+([.][0-9]+)?[NS]$'
            THEN LEFT(BTRIM(s.latitude), -1)::DOUBLE PRECISION
                 * CASE RIGHT(BTRIM(s.latitude), 1)
                       WHEN 'S' THEN -1.0 ELSE 1.0
                   END
            ELSE NULL
        END AS latitude,
        CASE
            WHEN BTRIM(s.longitude) ~ '^[0-9]+([.][0-9]+)?[EW]$'
            THEN LEFT(BTRIM(s.longitude), -1)::DOUBLE PRECISION
                 * CASE RIGHT(BTRIM(s.longitude), 1)
                       WHEN 'W' THEN -1.0 ELSE 1.0
                   END
            ELSE NULL
        END AS longitude,
        FALSE AS is_major_city
    FROM staging_city AS s

    UNION ALL

    SELECT
        NULLIF(BTRIM(s.city), ''),
        NULLIF(BTRIM(s.country), ''),
        CASE
            WHEN BTRIM(s.latitude) ~ '^[0-9]+([.][0-9]+)?[NS]$'
            THEN LEFT(BTRIM(s.latitude), -1)::DOUBLE PRECISION
                 * CASE RIGHT(BTRIM(s.latitude), 1)
                       WHEN 'S' THEN -1.0 ELSE 1.0
                   END
            ELSE NULL
        END,
        CASE
            WHEN BTRIM(s.longitude) ~ '^[0-9]+([.][0-9]+)?[EW]$'
            THEN LEFT(BTRIM(s.longitude), -1)::DOUBLE PRECISION
                 * CASE RIGHT(BTRIM(s.longitude), 1)
                       WHEN 'W' THEN -1.0 ELSE 1.0
                   END
            ELSE NULL
        END,
        TRUE
    FROM staging_major_city AS s
)
INSERT INTO dim_city (
    city_name,
    country_id,
    latitude,
    longitude,
    is_major_city
)
SELECT
    cs.city_name,
    c.country_id,
    cs.latitude,
    cs.longitude,
    BOOL_OR(cs.is_major_city)
FROM city_source AS cs
JOIN dim_country AS c
  ON c.country_name = cs.country_name
WHERE cs.city_name IS NOT NULL
  AND cs.country_name IS NOT NULL
  AND cs.latitude IS NOT NULL
  AND cs.longitude IS NOT NULL
GROUP BY
    cs.city_name,
    c.country_id,
    cs.latitude,
    cs.longitude
ORDER BY
    cs.city_name,
    c.country_id,
    cs.latitude,
    cs.longitude;

COMMIT;

BEGIN;

-- -----------------------------------------------------------------------------
-- Nạp fact global
-- -----------------------------------------------------------------------------

INSERT INTO fact_global_temperature (
    date_id,
    source_staging_id,
    land_average_temperature,
    land_average_temperature_uncertainty,
    land_max_temperature,
    land_max_temperature_uncertainty,
    land_min_temperature,
    land_min_temperature_uncertainty,
    land_and_ocean_average_temperature,
    land_and_ocean_average_temperature_uncertainty
)
SELECT
    d.date_id,
    s.staging_id,
    s.land_average_temperature,
    s.land_average_temperature_uncertainty,
    s.land_max_temperature,
    s.land_max_temperature_uncertainty,
    s.land_min_temperature,
    s.land_min_temperature_uncertainty,
    s.land_and_ocean_average_temperature,
    s.land_and_ocean_average_temperature_uncertainty
FROM staging_global AS s
JOIN dim_date AS d ON d.full_date = s.dt;


-- -----------------------------------------------------------------------------
-- Nạp fact country
-- -----------------------------------------------------------------------------

INSERT INTO fact_country_temperature (
    date_id,
    country_id,
    source_staging_id,
    average_temperature,
    average_temperature_uncertainty
)
SELECT
    d.date_id,
    c.country_id,
    s.staging_id,
    s.average_temperature,
    s.average_temperature_uncertainty
FROM staging_country AS s
JOIN dim_date AS d ON d.full_date = s.dt
JOIN dim_country AS c ON c.country_name = BTRIM(s.country);


-- -----------------------------------------------------------------------------
-- Nạp fact city
-- -----------------------------------------------------------------------------

WITH normalized_city AS (
    SELECT
        s.staging_id,
        s.dt,
        s.average_temperature,
        s.average_temperature_uncertainty,
        BTRIM(s.city) AS city_name,
        BTRIM(s.country) AS country_name,
        CASE
            WHEN BTRIM(s.latitude) ~ '^[0-9]+([.][0-9]+)?[NS]$'
            THEN LEFT(BTRIM(s.latitude), -1)::DOUBLE PRECISION
                 * CASE RIGHT(BTRIM(s.latitude), 1)
                       WHEN 'S' THEN -1.0 ELSE 1.0
                   END
            ELSE NULL
        END AS latitude,
        CASE
            WHEN BTRIM(s.longitude) ~ '^[0-9]+([.][0-9]+)?[EW]$'
            THEN LEFT(BTRIM(s.longitude), -1)::DOUBLE PRECISION
                 * CASE RIGHT(BTRIM(s.longitude), 1)
                       WHEN 'W' THEN -1.0 ELSE 1.0
                   END
            ELSE NULL
        END AS longitude
    FROM staging_city AS s
)
INSERT INTO fact_city_temperature (
    date_id,
    city_id,
    source_staging_id,
    average_temperature,
    average_temperature_uncertainty
)
SELECT
    d.date_id,
    ci.city_id,
    n.staging_id,
    n.average_temperature,
    n.average_temperature_uncertainty
FROM normalized_city AS n
JOIN dim_date AS d ON d.full_date = n.dt
JOIN dim_country AS c ON c.country_name = n.country_name
JOIN dim_city AS ci
  ON ci.country_id = c.country_id
 AND ci.city_name = n.city_name
 AND ci.latitude = n.latitude
 AND ci.longitude = n.longitude;


-- -----------------------------------------------------------------------------
-- Nạp fact major city
-- -----------------------------------------------------------------------------

WITH normalized_major_city AS (
    SELECT
        s.staging_id,
        s.dt,
        s.average_temperature,
        s.average_temperature_uncertainty,
        BTRIM(s.city) AS city_name,
        BTRIM(s.country) AS country_name,
        CASE
            WHEN BTRIM(s.latitude) ~ '^[0-9]+([.][0-9]+)?[NS]$'
            THEN LEFT(BTRIM(s.latitude), -1)::DOUBLE PRECISION
                 * CASE RIGHT(BTRIM(s.latitude), 1)
                       WHEN 'S' THEN -1.0 ELSE 1.0
                   END
            ELSE NULL
        END AS latitude,
        CASE
            WHEN BTRIM(s.longitude) ~ '^[0-9]+([.][0-9]+)?[EW]$'
            THEN LEFT(BTRIM(s.longitude), -1)::DOUBLE PRECISION
                 * CASE RIGHT(BTRIM(s.longitude), 1)
                       WHEN 'W' THEN -1.0 ELSE 1.0
                   END
            ELSE NULL
        END AS longitude
    FROM staging_major_city AS s
)
INSERT INTO fact_major_city_temperature (
    date_id,
    city_id,
    source_staging_id,
    average_temperature,
    average_temperature_uncertainty
)
SELECT
    d.date_id,
    ci.city_id,
    n.staging_id,
    n.average_temperature,
    n.average_temperature_uncertainty
FROM normalized_major_city AS n
JOIN dim_date AS d ON d.full_date = n.dt
JOIN dim_country AS c ON c.country_name = n.country_name
JOIN dim_city AS ci
  ON ci.country_id = c.country_id
 AND ci.city_name = n.city_name
 AND ci.latitude = n.latitude
 AND ci.longitude = n.longitude;

COMMIT;


-- -----------------------------------------------------------------------------
-- Validation fact counts và dimensions
-- -----------------------------------------------------------------------------

WITH expected(dataset, expected_rows) AS (
    VALUES
        ('global', 3192::BIGINT),
        ('country', 577462::BIGINT),
        ('city', 5637812::BIGINT),
        ('major_city', 239177::BIGINT)
),
actual(dataset, fact_table, actual_rows) AS (
    SELECT
        'global',
        'fact_global_temperature',
        COUNT(*)
    FROM fact_global_temperature
    UNION ALL
    SELECT
        'country',
        'fact_country_temperature',
        COUNT(*)
    FROM fact_country_temperature
    UNION ALL
    SELECT
        'city',
        'fact_city_temperature',
        COUNT(*)
    FROM fact_city_temperature
    UNION ALL
    SELECT
        'major_city',
        'fact_major_city_temperature',
        COUNT(*)
    FROM fact_major_city_temperature
)
SELECT
    e.dataset,
    a.fact_table,
    e.expected_rows,
    a.actual_rows,
    a.actual_rows - e.expected_rows AS difference,
    CASE
        WHEN a.actual_rows = e.expected_rows THEN 'PASS'
        ELSE 'FAIL'
    END AS status
FROM expected AS e
JOIN actual AS a USING (dataset)
ORDER BY e.dataset;

-- Row count của dimensions để tham khảo.
SELECT 'dim_date' AS table_name, COUNT(*) AS row_count FROM dim_date
UNION ALL
SELECT 'dim_country', COUNT(*) FROM dim_country
UNION ALL
SELECT 'dim_city', COUNT(*) FROM dim_city
ORDER BY table_name;
