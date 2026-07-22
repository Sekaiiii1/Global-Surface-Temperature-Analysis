-- =============================================================================
-- 02_import_data.sql
-- Server-side COPY statements used by notebooks/02_postgresql_pipeline.ipynb.
-- Run this script in pgAdmin 4 Query Tool while connected to climate_db.
-- PostgreSQL runs locally, so the service account must have Read permission
-- on data/raw. Replace the absolute project path if the repository is moved.
-- Empty, unquoted CSV fields are imported as SQL NULL values.
-- =============================================================================

BEGIN;

TRUNCATE TABLE
    staging_global,
    staging_country,
    staging_state,
    staging_city,
    staging_major_city
RESTART IDENTITY;

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

-- If any COPY fails, run ROLLBACK before correcting the path/permission issue.
