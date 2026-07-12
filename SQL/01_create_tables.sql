-- ==============================================================================
-- FILE: 01_create_tables.sql
-- MỤC TIÊU: Khởi tạo bảng Staging hứng dữ liệu và Schema chuẩn (Dim/Fact)
-- ==============================================================================

-- 1. XÓA CÁC BẢNG CŨ NẾU ĐÃ TỒN TẠI (Tránh lỗi khi chạy lại script nhiều lần)
DROP TABLE IF EXISTS fact_temperature CASCADE;
DROP TABLE IF EXISTS dim_city CASCADE;
DROP TABLE IF EXISTS dim_country CASCADE;
DROP TABLE IF EXISTS staging_global CASCADE;
DROP TABLE IF EXISTS staging_country CASCADE;
DROP TABLE IF EXISTS staging_major_city CASCADE;

-- ==============================================================================
-- PHẦN A: TẠO CÁC BẢNG STAGING (Landing Zone)
-- Hứng dữ liệu 100% giống cấu trúc cột của file CSV, không đặt ràng buộc NOT NULL
-- ==============================================================================

-- Staging 1: Dữ liệu Toàn cầu (GlobalTemperatures.csv)
CREATE TABLE staging_global (
    dt DATE,
    LandAverageTemperature NUMERIC,
    LandAverageTemperatureUncertainty NUMERIC,
    LandMaxTemperature NUMERIC,
    LandMaxTemperatureUncertainty NUMERIC,
    LandMinTemperature NUMERIC,
    LandMinTemperatureUncertainty NUMERIC,
    LandAndOceanAverageTemperature NUMERIC,
    LandAndOceanAverageTemperatureUncertainty NUMERIC
);

-- Staging 2: Dữ liệu Quốc gia (GlobalLandTemperaturesByCountry.csv)
CREATE TABLE staging_country (
    dt DATE,
    AverageTemperature NUMERIC,
    AverageTemperatureUncertainty NUMERIC,
    Country VARCHAR(255)
);

-- Staging 3: Dữ liệu Thành phố lớn (GlobalLandTemperaturesByMajorCity.csv)
CREATE TABLE staging_major_city (
    dt DATE,
    AverageTemperature NUMERIC,
    AverageTemperatureUncertainty NUMERIC,
    City VARCHAR(255),
    Country VARCHAR(255),
    Latitude VARCHAR(50),
    Longitude VARCHAR(50)
);

-- ==============================================================================
-- PHẦN B: TẠO CẤU TRÚC LƯU TRỮ CHUẨN MỰC (Star Schema)
-- Nơi sẽ lưu trữ dữ liệu SAU KHI đã được lọc thô và JOIN từ các bảng Staging
-- ==============================================================================

-- Bảng Dimension 1: Danh mục Quốc gia
CREATE TABLE dim_country (
    country_id SERIAL PRIMARY KEY,
    country_name VARCHAR(255) UNIQUE NOT NULL
);

-- Bảng Dimension 2: Danh mục Thành phố
CREATE TABLE dim_city (
    city_id SERIAL PRIMARY KEY,
    city_name VARCHAR(255) NOT NULL,
    country_id INT REFERENCES dim_country(country_id) ON DELETE CASCADE,
    latitude VARCHAR(50),
    longitude VARCHAR(50),
    UNIQUE (city_name, country_id) -- Chống trùng lặp tên thành phố trong cùng 1 quốc gia
);

-- Bảng Fact: Bảng sự kiện chứa dữ liệu nhiệt độ tổng hợp
-- Bảng này thiết kế sẵn các cột để đón dữ liệu từ City, Country và Global gộp lại
CREATE TABLE fact_temperature (
    record_id SERIAL PRIMARY KEY,
    city_id INT REFERENCES dim_city(city_id) ON DELETE CASCADE,
    record_date DATE NOT NULL,
    
    -- Dữ liệu cấp thành phố
    city_avg_temp NUMERIC,           
    city_temp_uncertainty NUMERIC,
    
    -- Dữ liệu cấp quốc gia (được JOIN vào)
    country_avg_temp NUMERIC,        
    
    -- Dữ liệu cấp toàn cầu (được JOIN vào)
    global_avg_temp NUMERIC          
);