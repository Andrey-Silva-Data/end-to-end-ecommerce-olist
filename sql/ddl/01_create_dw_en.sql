
-- PROJECT: OLIST E-COMMERCE END-TO-END
-- DATABASE: PostgreSQL / Neon
-- SCHEMA: dw_en
-- PURPOSE: International Data Warehouse
-- VERSION: 1.0

-- 1. CREATE SCHEMA
CREATE SCHEMA IF NOT EXISTS dw_en;



-- 2. DIMENSION: GEOLOCATION
CREATE TABLE IF NOT EXISTS dw_en.dim_geolocation (
    geolocation_key BIGSERIAL PRIMARY KEY,
    zip_code_prefix VARCHAR(10) NOT NULL UNIQUE,
    latitude NUMERIC(10, 8),
    longitude NUMERIC(11, 8),
    city VARCHAR(100) NOT NULL,
    state CHAR(2) NOT NULL
);

-- 3. DIMENSION: CUSTOMERS
CREATE TABLE IF NOT EXISTS dw_en.dim_customers (
    customer_key BIGSERIAL PRIMARY KEY,
    customer_id VARCHAR(50) NOT NULL UNIQUE,
    customer_unique_id VARCHAR(50) NOT NULL,
    zip_code_prefix VARCHAR(10),
    city VARCHAR(100),
    state VARCHAR(50),
    CONSTRAINT fk_customer_geolocation
        FOREIGN KEY (zip_code_prefix) REFERENCES dw_en.dim_geolocation(zip_code_prefix) ON DELETE SET NULL
);

-- 4. DIMENSION: SELLERS
CREATE TABLE IF NOT EXISTS dw_en.dim_sellers (
    seller_key BIGSERIAL PRIMARY KEY,
    seller_id VARCHAR(50) NOT NULL UNIQUE,
    zip_code_prefix VARCHAR(10),
    CONSTRAINT fk_seller_geolocation
        FOREIGN KEY (zip_code_prefix) REFERENCES dw_en.dim_geolocation(zip_code_prefix) ON DELETE SET NULL
);

-- 5. DIMENSION: PRODUCTS
CREATE TABLE IF NOT EXISTS dw_en.dim_products (
    product_key BIGSERIAL PRIMARY KEY,
    product_id VARCHAR(50) NOT NULL UNIQUE,
    product_category_name VARCHAR(100),
    product_name_length INT,
    product_description_length INT,
    product_photos_qty INT,
    product_weight_g INT CHECK (product_weight_g >= 0),
    product_length_cm INT CHECK (product_length_cm >= 0),
    product_height_cm INT CHECK (product_height_cm >= 0),
    product_width_cm INT  CHECK (product_width_cm >= 0)
);

-- 6. DIMENSION: DATE
CREATE TABLE IF NOT EXISTS dw_en.dim_date (
    date_key INT PRIMARY KEY,
    full_date DATE NOT NULL UNIQUE,
    year INT NOT NULL,
    month INT NOT NULL CHECK (month BETWEEN 1 AND 12),
    month_name VARCHAR(20) NOT NULL,
    day INT NOT NULL CHECK (day BETWEEN 1 AND 31),
    day_of_week INT NOT NULL CHECK (day_of_week BETWEEN 1 AND 7),
    day_name VARCHAR(20) NOT NULL,
    quarter INT NOT NULL CHECK (quarter BETWEEN 1 AND 4),
    is_weekend BOOLEAN NOT NULL
);



-- 7. FACT: SALES - GRAIN: ONE ROW PER ORDER ITEM

CREATE TABLE IF NOT EXISTS dw_en.fact_sales (
    sales_key BIGSERIAL PRIMARY KEY,
    order_id VARCHAR(50) NOT NULL,
    order_item_id INT NOT NULL CHECK (order_item_id > 0),

    -- Foreign keys
    customer_key BIGINT NOT NULL REFERENCES dw_en.dim_customers(customer_key),
    seller_key BIGINT NOT NULL REFERENCES dw_en.dim_sellers(seller_key),
    product_key BIGINT NOT NULL REFERENCES dw_en.dim_products(product_key),
    order_date_key INT NOT NULL REFERENCES dw_en.dim_date(date_key),
    delivery_date_key INT REFERENCES dw_en.dim_date(date_key),
    estimated_delivery_date_key INT REFERENCES dw_en.dim_date(date_key),

    -- Order information
    order_status VARCHAR(30) NOT NULL,

    -- Financial measures
    price NUMERIC(10, 2) NOT NULL CHECK (price >= 0),
    freight_value NUMERIC(10, 2) NOT NULL CHECK (freight_value >= 0),

    -- Operational timestamps
    shipping_limit_date TIMESTAMP,
    order_approved_at TIMESTAMP,
    shipped_at TIMESTAMP,
    delivered_at TIMESTAMP,
    estimated_delivery_date TIMESTAMP,

    -- Original item identification
    CONSTRAINT uq_order_item
        UNIQUE (order_id, order_item_id)
);


-- 8. FACT: PAYMENTS - GRAIN: ONE ROW PER PAYMENT SEQUENCE
CREATE TABLE IF NOT EXISTS dw_en.fact_payments (
    payment_key BIGSERIAL PRIMARY KEY,
    order_id VARCHAR(50) NOT NULL,
    customer_key BIGINT NOT NULL REFERENCES dw_en.dim_customers(customer_key),
    order_date_key INT NOT NULL  REFERENCES dw_en.dim_date(date_key),
    payment_sequential INT NOT NULL CHECK (payment_sequential > 0),
    payment_type VARCHAR(30) NOT NULL,
    payment_installments INT NOT NULL CHECK (payment_installments >= 0),
    payment_value NUMERIC(10, 2) NOT NULL CHECK (payment_value >= 0),
    CONSTRAINT uq_order_payment
        UNIQUE (order_id, payment_sequential)
);


-- 9. FACT: REVIEWS - GRAIN: ONE ROW PER REVIEW RECORD
CREATE TABLE IF NOT EXISTS dw_en.fact_reviews (
    review_key BIGSERIAL PRIMARY KEY,
    review_id VARCHAR(50) NOT NULL,
    order_id VARCHAR(50) NOT NULL,
    customer_key BIGINT NOT NULL REFERENCES dw_en.dim_customers(customer_key),
    review_answer_date_key INT REFERENCES dw_en.dim_date(date_key),
    review_score INT NOT NULL CHECK (review_score BETWEEN 1 AND 5),
    review_comment_title TEXT,
    review_comment_message TEXT,
    review_created_at TIMESTAMP,
    review_answered_at TIMESTAMP
);