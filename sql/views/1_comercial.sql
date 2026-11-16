
-- OLIST DATA WAREHOUSE
-- ANALYTICAL LAYER: COMMERCIAL
-- File: 1_comercial.sql
-- Schema: dw_en
--
-- BUSINESS RULES:
-- 1. Sales and revenue: delivered orders only.
-- 2. Seasonality: Southern Hemisphere.
-- 3. Product ranking: individual products and categories.
-- 4. Sales grain: one row per order item.


-- 01. SALES OVERVIEW
-- General commercial performance

CREATE OR REPLACE VIEW dw_en.vw_sales_overview AS

SELECT
    COUNT(*) AS total_items_sold,

    COUNT(DISTINCT order_id) AS total_orders,

    COUNT(DISTINCT product_key) AS distinct_products_sold,

    SUM(price) AS total_product_revenue,

    SUM(freight_value) AS total_freight_revenue,

    SUM(price + freight_value) AS total_revenue_including_freight,

    ROUND(
        SUM(price) / NULLIF(COUNT(DISTINCT order_id), 0),
        2
    ) AS average_order_value

FROM dw_en.fact_sales

WHERE order_status = 'delivered';



-- 02. PRODUCT SALES RANKING
-- Individual product ranking


CREATE OR REPLACE VIEW dw_en.vw_product_sales_ranking AS

WITH product_sales AS (

    SELECT
        p.product_key,
        p.product_id,
        COALESCE(p.product_category_name, 'unknown')
            AS product_category_name,

        COUNT(*) AS items_sold,

        COUNT(DISTINCT fs.order_id) AS total_orders,

        SUM(fs.price) AS product_revenue,

        SUM(fs.freight_value) AS freight_revenue

    FROM dw_en.fact_sales fs

    INNER JOIN dw_en.dim_products p
        ON fs.product_key = p.product_key

    WHERE fs.order_status = 'delivered'

    GROUP BY
        p.product_key,
        p.product_id,
        p.product_category_name
)

SELECT
    ROW_NUMBER() OVER (
        ORDER BY items_sold DESC, product_id
    ) AS ranking_position,

    product_key,
    product_id,
    product_category_name,
    items_sold,
    total_orders,
    product_revenue,
    freight_revenue

FROM product_sales;



-- 03. CATEGORY SALES RANKING
-- Product category ranking


CREATE OR REPLACE VIEW dw_en.vw_category_sales_ranking AS

SELECT
    ROW_NUMBER() OVER (
        ORDER BY COUNT(*) DESC, 
                 COALESCE(p.product_category_name, 'unknown')
    ) AS ranking_position,

    COALESCE(p.product_category_name, 'unknown')
        AS product_category_name,

    COUNT(*) AS items_sold,

    COUNT(DISTINCT fs.product_key) AS distinct_products,

    COUNT(DISTINCT fs.order_id) AS total_orders,

    SUM(fs.price) AS category_revenue,

    SUM(fs.freight_value) AS freight_revenue

FROM dw_en.fact_sales fs

INNER JOIN dw_en.dim_products p
    ON fs.product_key = p.product_key

WHERE fs.order_status = 'delivered'

GROUP BY
    COALESCE(p.product_category_name, 'unknown');



-- 04. PRODUCT SEASONAL SALES
-- Individual product sales by season



CREATE OR REPLACE VIEW dw_en.vw_product_seasonal_sales AS

WITH base AS (
    SELECT
        p.product_id,
        COALESCE(p.product_category_name, 'unknown')
            AS product_category_name,

        CASE
            WHEN d.month IN (12, 1, 2) THEN 'Summer'
            WHEN d.month IN (3, 4, 5) THEN 'Autumn'
            WHEN d.month IN (6, 7, 8) THEN 'Winter'
            ELSE 'Spring'
        END AS season,

        CASE
            WHEN d.month = 12 THEN d.year + 1
            ELSE d.year
        END AS season_year,

        fs.order_id,
        fs.price

    FROM dw_en.fact_sales fs

    JOIN dw_en.dim_products p
        ON fs.product_key = p.product_key

    JOIN dw_en.dim_date d
        ON fs.order_date_key = d.date_key

    WHERE fs.order_status = 'delivered'
),

seasonal_sales AS (
    SELECT
        product_id,
        product_category_name,
        season,
        season_year,
        COUNT(*) AS items_sold,
        COUNT(DISTINCT order_id) AS total_orders,
        SUM(price) AS product_revenue

    FROM base

    GROUP BY
        product_id,
        product_category_name,
        season,
        season_year
)

SELECT
    *,
    DENSE_RANK() OVER (
        PARTITION BY season_year, season
        ORDER BY items_sold DESC
    ) AS ranking_position

FROM seasonal_sales;



-- 05. CATEGORY SEASONAL SALES
-- Category performance by season

CREATE OR REPLACE VIEW dw_en.vw_category_seasonal_sales AS

WITH base AS (
    SELECT
        COALESCE(p.product_category_name, 'unknown')
            AS product_category_name,

        CASE
            WHEN d.month IN (12, 1, 2) THEN 'Summer'
            WHEN d.month IN (3, 4, 5) THEN 'Autumn'
            WHEN d.month IN (6, 7, 8) THEN 'Winter'
            ELSE 'Spring'
        END AS season,

        CASE
            WHEN d.month = 12 THEN d.year + 1
            ELSE d.year
        END AS season_year,

        fs.product_key,
        fs.order_id,
        fs.price

    FROM dw_en.fact_sales fs

    JOIN dw_en.dim_products p
        ON fs.product_key = p.product_key

    JOIN dw_en.dim_date d
        ON fs.order_date_key = d.date_key

    WHERE fs.order_status = 'delivered'
),

seasonal_sales AS (
    SELECT
        product_category_name,
        season,
        season_year,
        COUNT(*) AS items_sold,
        COUNT(DISTINCT product_key) AS distinct_products,
        COUNT(DISTINCT order_id) AS total_orders,
        SUM(price) AS category_revenue

    FROM base

    GROUP BY
        product_category_name,
        season,
        season_year
)

SELECT
    *,
    DENSE_RANK() OVER (
        PARTITION BY season_year, season
        ORDER BY items_sold DESC
    ) AS ranking_position

FROM seasonal_sales;



-- 06. PRODUCT RANKING EVOLUTION
-- Monthly product ranking evolution


CREATE OR REPLACE VIEW dw_en.vw_product_ranking_evolution AS

WITH monthly_sales AS (

    SELECT
        p.product_id,

        COALESCE(p.product_category_name, 'unknown')
            AS product_category_name,

        d.year,
        d.month,

        COUNT(*) AS items_sold,

        SUM(fs.price) AS product_revenue

    FROM dw_en.fact_sales fs

    INNER JOIN dw_en.dim_products p
        ON fs.product_key = p.product_key

    INNER JOIN dw_en.dim_date d
        ON fs.order_date_key = d.date_key

    WHERE fs.order_status = 'delivered'

    GROUP BY
        p.product_id,
        p.product_category_name,
        d.year,
        d.month
),

monthly_ranking AS (

    SELECT
        *,

        DENSE_RANK() OVER (
            PARTITION BY year, month
            ORDER BY items_sold DESC
        ) AS ranking_position

    FROM monthly_sales
),

ranking_evolution AS (

    SELECT
        *,

        LAG(ranking_position) OVER (
            PARTITION BY product_id
            ORDER BY year, month
        ) AS previous_ranking

    FROM monthly_ranking
)

SELECT
    *,

    previous_ranking - ranking_position AS ranking_change

FROM ranking_evolution;



-- 07. CATEGORY RANKING EVOLUTION
-- Monthly category ranking evolution


CREATE OR REPLACE VIEW dw_en.vw_category_ranking_evolution AS

WITH monthly_sales AS (

    SELECT
        COALESCE(p.product_category_name, 'unknown')
            AS product_category_name,

        d.year,
        d.month,

        COUNT(*) AS items_sold,

        SUM(fs.price) AS category_revenue

    FROM dw_en.fact_sales fs

    INNER JOIN dw_en.dim_products p
        ON fs.product_key = p.product_key

    INNER JOIN dw_en.dim_date d
        ON fs.order_date_key = d.date_key

    WHERE fs.order_status = 'delivered'

    GROUP BY
        p.product_category_name,
        d.year,
        d.month
),

monthly_ranking AS (

    SELECT
        *,

        DENSE_RANK() OVER (
            PARTITION BY year, month
            ORDER BY items_sold DESC
        ) AS ranking_position

    FROM monthly_sales
),

ranking_evolution AS (

    SELECT
        *,

        LAG(ranking_position) OVER (
            PARTITION BY product_category_name
            ORDER BY year, month
        ) AS previous_ranking

    FROM monthly_ranking
)

SELECT
    *,

    previous_ranking - ranking_position AS ranking_change

FROM ranking_evolution;



-- 08. MONTHLY REVENUE
-- Revenue by year and month


CREATE OR REPLACE VIEW dw_en.vw_revenue_monthly AS

SELECT
    d.year,
    d.month,
    d.month_name,

    SUM(fs.price) AS product_revenue,

    SUM(fs.freight_value) AS freight_revenue,

    SUM(fs.price + fs.freight_value)
        AS total_revenue_including_freight,

    COUNT(DISTINCT fs.order_id) AS total_orders

FROM dw_en.fact_sales fs

INNER JOIN dw_en.dim_date d
    ON fs.order_date_key = d.date_key

WHERE fs.order_status = 'delivered'

GROUP BY
    d.year,
    d.month,
    d.month_name;



-- 09. SEASONAL REVENUE
-- Revenue by Southern Hemisphere season


CREATE OR REPLACE VIEW dw_en.vw_revenue_seasonal AS

SELECT
    CASE
        WHEN d.month IN (12, 1, 2) THEN 'Summer'
        WHEN d.month IN (3, 4, 5) THEN 'Autumn'
        WHEN d.month IN (6, 7, 8) THEN 'Winter'
        ELSE 'Spring'
    END AS season,

    CASE
        WHEN d.month = 12 THEN d.year + 1
        ELSE d.year
    END AS season_year,

    SUM(fs.price) AS product_revenue,
    SUM(fs.freight_value) AS freight_revenue,

    SUM(fs.price + fs.freight_value)
        AS total_revenue_including_freight,

    COUNT(DISTINCT fs.order_id) AS total_orders

FROM dw_en.fact_sales fs

JOIN dw_en.dim_date d
    ON fs.order_date_key = d.date_key

WHERE fs.order_status = 'delivered'

GROUP BY
    CASE
        WHEN d.month IN (12, 1, 2) THEN 'Summer'
        WHEN d.month IN (3, 4, 5) THEN 'Autumn'
        WHEN d.month IN (6, 7, 8) THEN 'Winter'
        ELSE 'Spring'
    END,

    CASE
        WHEN d.month = 12 THEN d.year + 1
        ELSE d.year
    END;




-- 10. MONTHLY ORDERS
-- Number of delivered orders by month


CREATE OR REPLACE VIEW dw_en.vw_orders_monthly AS

SELECT
    d.year,
    d.month,
    d.month_name,

    COUNT(DISTINCT fs.order_id) AS total_orders,

    COUNT(*) AS total_items_sold

FROM dw_en.fact_sales fs

INNER JOIN dw_en.dim_date d
    ON fs.order_date_key = d.date_key

WHERE fs.order_status = 'delivered'

GROUP BY
    d.year,
    d.month,
    d.month_name;



-- 11. SEASONAL ORDERS
-- Number of delivered orders by season



CREATE OR REPLACE VIEW dw_en.vw_orders_seasonal AS

SELECT
    CASE
        WHEN d.month IN (12, 1, 2) THEN 'Summer'
        WHEN d.month IN (3, 4, 5) THEN 'Autumn'
        WHEN d.month IN (6, 7, 8) THEN 'Winter'
        ELSE 'Spring'
    END AS season,

    CASE
        WHEN d.month = 12 THEN d.year + 1
        ELSE d.year
    END AS season_year,

    COUNT(DISTINCT fs.order_id) AS total_orders,

    COUNT(*) AS total_items_sold

FROM dw_en.fact_sales fs

JOIN dw_en.dim_date d
    ON fs.order_date_key = d.date_key

WHERE fs.order_status = 'delivered'

GROUP BY
    CASE
        WHEN d.month IN (12, 1, 2) THEN 'Summer'
        WHEN d.month IN (3, 4, 5) THEN 'Autumn'
        WHEN d.month IN (6, 7, 8) THEN 'Winter'
        ELSE 'Spring'
    END,

    CASE
        WHEN d.month = 12 THEN d.year + 1
        ELSE d.year
    END;




-- 12. ORDER STATUS PERFORMANCE
-- Delivered and canceled percentages
-- All order statuses are included in this view.


CREATE OR REPLACE VIEW dw_en.vw_order_status_performance AS

WITH unique_orders AS (

    SELECT DISTINCT
        order_id,
        order_status

    FROM dw_en.fact_sales
),

status_totals AS (

    SELECT
        order_status,

        COUNT(*) AS total_orders

    FROM unique_orders

    GROUP BY order_status
)

SELECT
    order_status,

    total_orders,

    ROUND(
        100.0 * total_orders /
        NULLIF(SUM(total_orders) OVER (), 0),
        2
    ) AS percentage_of_orders

FROM status_totals;



-- 13. CATEGORY SALES PERFORMANCE
-- Revenue and volume by category


CREATE OR REPLACE VIEW dw_en.vw_category_sales_performance AS

SELECT
    COALESCE(p.product_category_name, 'unknown')
        AS product_category_name,

    COUNT(*) AS items_sold,

    COUNT(DISTINCT fs.product_key) AS distinct_products,

    COUNT(DISTINCT fs.order_id) AS total_orders,

    SUM(fs.price) AS product_revenue,

    SUM(fs.freight_value) AS freight_revenue,

    ROUND(
        100.0 * SUM(fs.price) /
        NULLIF(
            SUM(SUM(fs.price)) OVER (),
            0
        ),
        2
    ) AS revenue_share_percentage

FROM dw_en.fact_sales fs

INNER JOIN dw_en.dim_products p
    ON fs.product_key = p.product_key

WHERE fs.order_status = 'delivered'

GROUP BY
    COALESCE(p.product_category_name, 'unknown');
