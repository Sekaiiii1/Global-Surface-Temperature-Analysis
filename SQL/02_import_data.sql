-- =============================================================================
-- 02_import_data.sql
-- Import CSV, kiểm tra staging, cắt trực tiếp dữ liệu City, rồi nạp dimension/fact.
-- Chạy trong pgAdmin 4 Query Tool khi đang kết nối database climate_db.
--
-- LƯU Ý:
-- - Các bảng phải mới và đang rỗng do 01_create_tables.sql tạo ra.
-- - COPY là server-side COPY: tài khoản dịch vụ PostgreSQL cần quyền đọc data/raw.
-- - Sửa đường dẫn tuyệt đối bên dưới nếu repository được đặt ở vị trí khác.
-- - Nếu một COPY thất bại, transaction import sẽ bị hủy; chạy ROLLBACK nếu
--   Query Tool vẫn còn ở trạng thái aborted, sửa lỗi đường dẫn/quyền rồi import lại.
-- - Dữ liệu City được cắt trực tiếp trên staging_city và không thể phục hồi nếu
--   không import lại CSV nguồn.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. Import năm tệp CSV vào staging.
-- -----------------------------------------------------------------------------

BEGIN;


-- GlobalTemperatures.csv
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
    FORMAT CSV, HEADER TRUE, DELIMITER ',', QUOTE '"', ESCAPE '"',
    NULL '', ENCODING 'UTF8'
);

-- GlobalLandTemperaturesByCountry.csv
COPY staging_country (
    dt,
    average_temperature,
    average_temperature_uncertainty,
    country
)
FROM 'E:/FPT/HocKy3/PROJECT_1/PROJECT/Global-Surface-Temperature-Analysis/data/raw/GlobalLandTemperaturesByCountry.csv'
WITH (
    FORMAT CSV, HEADER TRUE, DELIMITER ',', QUOTE '"', ESCAPE '"',
    NULL '', ENCODING 'UTF8'
);

-- GlobalLandTemperaturesByState.csv
COPY staging_state (
    dt,
    average_temperature,
    average_temperature_uncertainty,
    state,
    country
)
FROM 'E:/FPT/HocKy3/PROJECT_1/PROJECT/Global-Surface-Temperature-Analysis/data/raw/GlobalLandTemperaturesByState.csv'
WITH (
    FORMAT CSV, HEADER TRUE, DELIMITER ',', QUOTE '"', ESCAPE '"',
    NULL '', ENCODING 'UTF8'
);

-- GlobalLandTemperaturesByCity.csv
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
    FORMAT CSV, HEADER TRUE, DELIMITER ',', QUOTE '"', ESCAPE '"',
    NULL '', ENCODING 'UTF8'
);

-- GlobalLandTemperaturesByMajorCity.csv
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
    FORMAT CSV, HEADER TRUE, DELIMITER ',', QUOTE '"', ESCAPE '"',
    NULL '', ENCODING 'UTF8'
);

COMMIT;

-- -----------------------------------------------------------------------------
-- 2. Kiểm tra số dòng và duplicate sau import.
-- City nguyên bản phải có 8.599.212 dòng trước khi cắt ở phần kế tiếp.
-- -----------------------------------------------------------------------------

WITH expected(dataset, expected_rows) AS (
    VALUES
        ('global', 3192::BIGINT),
        ('country', 577462::BIGINT),
        ('state', 645675::BIGINT),
        ('city', 8599212::BIGINT), -- Dữ liệu City nguyên bản, trước khi cắt ở Mục 8.
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
        'state',
        COUNT(*),
        MIN(staging_id),
        MAX(staging_id),
        COUNT(*) FILTER (WHERE loaded_at IS NULL)
    FROM staging_state
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

-- Duplicate theo grain nghiệp vụ; giá trị 0 là kết quả mong đợi.
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
    'state',
    COUNT(*) - COUNT(DISTINCT (dt, state, country))
FROM staging_state
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
-- 3. Kiểm tra điều kiện đầu vào và giữ cố định 80 quốc gia trong staging_city.
-- -----------------------------------------------------------------------------

-- Danh sách 20 quốc gia lớn/bắt buộc theo yêu cầu của bước cắt dữ liệu.
WITH mandatory_countries(country) AS (
    VALUES
        ('Vietnam'), ('United States'), ('China'), ('India'), ('Russia'),
        ('Brazil'), ('Japan'), ('Germany'), ('United Kingdom'), ('France'),
        ('Canada'), ('Australia'), ('Italy'), ('South Korea'), ('Mexico'),
        ('Indonesia'), ('Turkey'), ('Saudi Arabia'), ('Spain'), ('South Africa')
),
source_countries AS (
    SELECT DISTINCT country
    FROM staging_city
    WHERE NULLIF(BTRIM(country), '') IS NOT NULL
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
    (SELECT COUNT(*) FROM source_countries) AS distinct_countries,
    s.invalid_country_rows,
    (
        SELECT COUNT(*)
        FROM mandatory_countries AS m
        JOIN source_countries AS c USING (country)
    ) AS mandatory_countries_found,
    ARRAY(
        SELECT m.country
        FROM mandatory_countries AS m
        LEFT JOIN source_countries AS c USING (country)
        WHERE c.country IS NULL
        ORDER BY m.country
    ) AS missing_mandatory_countries
FROM source_stats AS s;

BEGIN;

-- Tạo manifest cố định gồm 80 quốc gia để kết quả không đổi giữa các lần chạy.
CREATE TABLE city_target_countries (
    country TEXT PRIMARY KEY,
    selection_group TEXT NOT NULL CHECK (
        selection_group IN ('mandatory', 'additional')
    )
);

INSERT INTO city_target_countries (country, selection_group)
VALUES
    ('Vietnam', 'mandatory'),
    ('United States', 'mandatory'),
    ('China', 'mandatory'),
    ('India', 'mandatory'),
    ('Russia', 'mandatory'),
    ('Brazil', 'mandatory'),
    ('Japan', 'mandatory'),
    ('Germany', 'mandatory'),
    ('United Kingdom', 'mandatory'),
    ('France', 'mandatory'),
    ('Canada', 'mandatory'),
    ('Australia', 'mandatory'),
    ('Italy', 'mandatory'),
    ('South Korea', 'mandatory'),
    ('Mexico', 'mandatory'),
    ('Indonesia', 'mandatory'),
    ('Turkey', 'mandatory'),
    ('Saudi Arabia', 'mandatory'),
    ('Spain', 'mandatory'),
    ('South Africa', 'mandatory'),
    ('Algeria', 'additional'),
    ('Angola', 'additional'),
    ('Azerbaijan', 'additional'),
    ('Bahrain', 'additional'),
    ('Bangladesh', 'additional'),
    ('Bolivia', 'additional'),
    ('Botswana', 'additional'),
    ('Burundi', 'additional'),
    ('Cameroon', 'additional'),
    ('Chad', 'additional'),
    ('Colombia', 'additional'),
    ('Congo (Democratic Republic Of The)', 'additional'),
    ('Costa Rica', 'additional'),
    ('Denmark', 'additional'),
    ('Djibouti', 'additional'),
    ('Ecuador', 'additional'),
    ('El Salvador', 'additional'),
    ('Eritrea', 'additional'),
    ('Finland', 'additional'),
    ('Gabon', 'additional'),
    ('Ghana', 'additional'),
    ('Guinea Bissau', 'additional'),
    ('Haiti', 'additional'),
    ('Iran', 'additional'),
    ('Iraq', 'additional'),
    ('Kazakhstan', 'additional'),
    ('Laos', 'additional'),
    ('Lebanon', 'additional'),
    ('Lesotho', 'additional'),
    ('Libya', 'additional'),
    ('Lithuania', 'additional'),
    ('Macedonia', 'additional'),
    ('Madagascar', 'additional'),
    ('Malaysia', 'additional'),
    ('Mauritius', 'additional'),
    ('Moldova', 'additional'),
    ('Mozambique', 'additional'),
    ('New Zealand', 'additional'),
    ('Nicaragua', 'additional'),
    ('Norway', 'additional'),
    ('Oman', 'additional'),
    ('Panama', 'additional'),
    ('Poland', 'additional'),
    ('Romania', 'additional'),
    ('Rwanda', 'additional'),
    ('Serbia', 'additional'),
    ('Sierra Leone', 'additional'),
    ('Slovakia', 'additional'),
    ('Slovenia', 'additional'),
    ('Sudan', 'additional'),
    ('Swaziland', 'additional'),
    ('Switzerland', 'additional'),
    ('Syria', 'additional'),
    ('Togo', 'additional'),
    ('Turkmenistan', 'additional'),
    ('Ukraine', 'additional'),
    ('Uruguay', 'additional'),
    ('Uzbekistan', 'additional'),
    ('Yemen', 'additional'),
    ('Zambia', 'additional');

-- Dừng transaction nếu danh sách không có đúng 20 + 60 quốc gia.
DO $$
DECLARE
    total_count INTEGER;
    mandatory_count INTEGER;
BEGIN
    SELECT
        COUNT(*),
        COUNT(*) FILTER (WHERE selection_group = 'mandatory')
    INTO total_count, mandatory_count
    FROM city_target_countries;

    IF total_count <> 80 OR mandatory_count <> 20 THEN
        RAISE EXCEPTION
            'Danh sách mục tiêu không hợp lệ: tổng %, bắt buộc %.',
            total_count, mandatory_count;
    END IF;
END
$$;

-- Xóa trực tiếp các dòng không thuộc danh sách 80 quốc gia.
DELETE FROM staging_city AS s
WHERE NOT EXISTS (
    SELECT 1
    FROM city_target_countries AS t
    WHERE t.country = s.country
);

-- Không cho phép commit nếu kết quả lọc quốc gia sai data contract.
DO $$
DECLARE
    remaining_rows BIGINT;
    remaining_countries INTEGER;
    mandatory_retained INTEGER;
BEGIN
    SELECT COUNT(*), COUNT(DISTINCT country)
    INTO remaining_rows, remaining_countries
    FROM staging_city;

    SELECT COUNT(DISTINCT s.country)
    INTO mandatory_retained
    FROM staging_city AS s
    JOIN city_target_countries AS t USING (country)
    WHERE t.selection_group = 'mandatory';

    IF remaining_rows <> 6907065
       OR remaining_countries <> 80
       OR mandatory_retained <> 20 THEN
        RAISE EXCEPTION
            'Lọc quốc gia sai data contract: rows %, countries %, mandatory %.',
            remaining_rows, remaining_countries, mandatory_retained;
    END IF;
END
$$;

COMMIT;

ANALYZE staging_city;

-- Kiểm tra kết quả sau khi chỉ lọc theo quốc gia.
SELECT
    COUNT(*) AS rows_after_country_filter,
    COUNT(DISTINCT country) AS selected_countries,
    COUNT(DISTINCT country) FILTER (
        WHERE country IN (
            SELECT country
            FROM city_target_countries
            WHERE selection_group = 'mandatory'
        )
    ) AS mandatory_countries_retained,
    MIN(dt) AS min_date,
    MAX(dt) AS max_date,
    COUNT(*) FILTER (WHERE average_temperature IS NULL)
        AS missing_temperature_rows,
    CASE
        WHEN COUNT(*) = 6907065
         AND COUNT(DISTINCT country) = 80
         AND COUNT(DISTINCT country) FILTER (
             WHERE country IN (
                 SELECT country
                 FROM city_target_countries
                 WHERE selection_group = 'mandatory'
             )
         ) = 20
        THEN 'PASS'
        ELSE 'FAIL'
    END AS status
FROM staging_city;

-- -----------------------------------------------------------------------------
-- 4. Giới hạn staging_city trong giai đoạn 1863-01-01 đến trước 2014-01-01.
-- Data contract cuối: 5.010.113 dòng thuộc 80 quốc gia.
-- -----------------------------------------------------------------------------

-- Đánh giá dải thời gian trước khi tạo bảng City cuối cùng.
SELECT
    COUNT(*) AS rows_before_time_filter,
    MIN(dt) AS min_date_before_filter,
    MAX(dt) AS max_date_before_filter,
    COUNT(DISTINCT dt) AS distinct_dates_before_filter,
    COUNT(*) FILTER (WHERE dt IS NULL) AS null_date_rows
FROM staging_city;

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
        COUNT(DISTINCT country),
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

    IF checked_rows <> 5010113
       OR checked_countries <> 80
       OR checked_dates <> 1809
       OR checked_min_date <> DATE '1863-01-01'
       OR checked_max_date <> DATE '2013-09-01'
       OR checked_missing_temperature <> 43101
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
        COUNT(DISTINCT country) AS final_countries,
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
        WHEN final_rows = 5010113
         AND final_countries = 80
         AND final_distinct_dates = 1809
         AND final_min_date = DATE '1863-01-01'
         AND final_max_date = DATE '2013-09-01'
         AND missing_temperature_rows = 43101
         AND invalid_date_rows = 0
        THEN 'PASS'
        ELSE 'FAIL'
    END AS status
FROM validation;

-- -----------------------------------------------------------------------------
-- 5. Nạp dimension tables.
-- -----------------------------------------------------------------------------

BEGIN;

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
    SELECT dt FROM staging_state WHERE dt IS NOT NULL
    UNION
    SELECT dt FROM staging_city WHERE dt IS NOT NULL
    UNION
    SELECT dt FROM staging_major_city WHERE dt IS NOT NULL
) AS source_dates
ORDER BY full_date;

INSERT INTO dim_country (country_name)
SELECT country_name
FROM (
    SELECT NULLIF(BTRIM(country), '') AS country_name FROM staging_country
    UNION
    SELECT NULLIF(BTRIM(country), '') FROM staging_state
    UNION
    SELECT NULLIF(BTRIM(country), '') FROM staging_city
    UNION
    SELECT NULLIF(BTRIM(country), '') FROM staging_major_city
) AS source_countries
WHERE country_name IS NOT NULL
ORDER BY country_name;

INSERT INTO dim_state (state_name, country_id)
SELECT DISTINCT BTRIM(s.state), c.country_id
FROM staging_state AS s
JOIN dim_country AS c
  ON c.country_name = BTRIM(s.country)
WHERE NULLIF(BTRIM(s.state), '') IS NOT NULL
ORDER BY BTRIM(s.state), c.country_id;

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

-- -----------------------------------------------------------------------------
-- 6. Nạp fact tables và bảo toàn source_staging_id để truy vết nguồn.
-- -----------------------------------------------------------------------------

BEGIN;

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

INSERT INTO fact_state_temperature (
    date_id,
    state_id,
    source_staging_id,
    average_temperature,
    average_temperature_uncertainty
)
SELECT
    d.date_id,
    st.state_id,
    s.staging_id,
    s.average_temperature,
    s.average_temperature_uncertainty
FROM staging_state AS s
JOIN dim_date AS d ON d.full_date = s.dt
JOIN dim_country AS c ON c.country_name = BTRIM(s.country)
JOIN dim_state AS st
  ON st.country_id = c.country_id
 AND st.state_name = BTRIM(s.state);

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
-- 7. Xác minh số dòng fact và tham khảo số dòng dimension.
-- -----------------------------------------------------------------------------

WITH expected(dataset, expected_rows) AS (
    VALUES
        ('global', 3192::BIGINT),
        ('country', 577462::BIGINT),
        ('state', 645675::BIGINT),
        ('city', 5010113::BIGINT),
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
        'state',
        'fact_state_temperature',
        COUNT(*)
    FROM fact_state_temperature
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
SELECT 'dim_state', COUNT(*) FROM dim_state
UNION ALL
SELECT 'dim_city', COUNT(*) FROM dim_city
ORDER BY table_name;
