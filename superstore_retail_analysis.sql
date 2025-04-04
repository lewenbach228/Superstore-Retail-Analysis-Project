-- =============================================
-- SUPERSTORE RETAIL ANALYSIS - SQL SCRIPT
-- Data Source: Kaggle Superstore Sales Dataset
-- Author: AGBONAGBAN Ablamvi
-- Last Updated: 04/04/2025
-- =============================================
-- ################################################################
-- SECTION 1: DATA PREPARATION AND CLEANING
-- ################################################################
-- ======================
-- DATE FORMAT CONVERSION
-- ======================
/*
Converts text dates (DD/MM/YYYY) to proper DATE format
Handles potential invalid dates with REGEX validation
 */
-- Create temporary columns for date conversion
ALTER TABLE superstore
ADD COLUMN `order_date_proper` DATE,
ADD COLUMN `ship_date_proper` DATE;

-- Convert Order Date
UPDATE superstore
SET
    `order_date_proper` = STR_TO_DATE (`Order Date`, '%d/%m/%Y')
WHERE
    `Order Date` REGEXP '^[0-9]{2}/[0-9]{2}/[0-9]{4}$';

-- Convert Ship Date
UPDATE superstore
SET
    `ship_date_proper` = STR_TO_DATE (`Ship Date`, '%d/%m/%Y')
WHERE
    `Ship Date` REGEXP '^[0-9]{2}/[0-9]{2}/[0-9]{4}$';

-- Verify conversions
SELECT
    `Order Date`,
    `order_date_proper`,
    `Ship Date`,
    `ship_date_proper`
FROM
    superstore
LIMIT
    10;

-- ======================
-- FINALIZE DATE COLUMNS
-- ======================
-- Replace original columns with cleaned versions
ALTER TABLE superstore
DROP COLUMN `Order Date`,
DROP COLUMN `Ship Date`;

ALTER TABLE superstore CHANGE COLUMN `order_date_proper` `Order Date` DATE,
CHANGE COLUMN `ship_date_proper` `Ship Date` DATE;

-- ################################################################
-- SECTION 2: DATA QUALITY CHECKS
-- ################################################################
-- ======================
-- DATA VALIDATION
-- ======================
/*
Identifies data integrity issues:
- Illogical date sequences
- Missing values
- Negative sales
 */
SELECT
    COUNT(
        CASE
            WHEN `Ship Date` < `Order Date` THEN 1
        END
    ) AS illogical_shipments,
    COUNT(
        CASE
            WHEN `Sales` <= 0 THEN 1
        END
    ) AS non_positive_sales,
    COUNT(
        CASE
            WHEN `Customer ID` IS NULL THEN 1
        END
    ) AS missing_customers,
    COUNT(
        CASE
            WHEN `Order Date` IS NULL THEN 1
        END
    ) AS missing_order_dates
FROM
    superstore;

-- ################################################################
-- SECTION 3: CORE BUSINESS ANALYSIS
-- ################################################################
-- ======================
-- SALES BY CATEGORY
-- ======================
/*
Analyzes sales distribution across product categories
Identifies top performing categories
 */
SELECT
    Category,
    ROUND(SUM(Sales), 2) AS total_sales,
    ROUND(
        SUM(Sales) * 100.0 / (
            SELECT
                SUM(Sales)
            FROM
                superstore
        ),
        2
    ) AS sales_percentage
FROM
    superstore
GROUP BY
    Category
ORDER BY
    total_sales DESC;

-- ======================
-- MONTHLY SALES TRENDS
-- ======================
/*
Calculates month-over-month sales growth
Identifies seasonal patterns
 */
WITH
    monthly_sales AS (
        SELECT
            DATE_FORMAT (`Order Date`, '%Y-%m-01') AS month,
            SUM(Sales) AS monthly_sales
        FROM
            superstore
        GROUP BY
            month
    )
SELECT
    month,
    ROUND(monthly_sales, 2),
    ROUND(
        LAG (monthly_sales) OVER (
            ORDER BY
                month
        ),
        2
    ) AS prev_month_sales,
    ROUND(
        (
            monthly_sales - LAG (monthly_sales) OVER (
                ORDER BY
                    month
            )
        ) / LAG (monthly_sales) OVER (
            ORDER BY
                month
        ) * 100,
        2
    ) AS growth_percentage
FROM
    monthly_sales
ORDER BY
    month;

-- ################################################################
-- SECTION 3: ADVANCED ANALYTICS
-- ################################################################
-- ======================
-- RFM CUSTOMER ANALYSIS
-- ======================
/*
Segments customers by:
- Recency (days since last order)
- Frequency (order count)
- Monetary value (total spend)
 */
WITH
    rfm_data AS (
        SELECT
            `Customer ID`,
            `Customer Name`,
            DATEDIFF (CURRENT_DATE, MAX(`Order Date`)) AS recency,
            COUNT(DISTINCT `Order ID`) AS frequency,
            ROUND(SUM(`Sales`), 2) AS monetary
        FROM
            superstore
        GROUP BY
            `Customer ID`,
            `Customer Name`
    )
SELECT
    `Customer Name`,
    recency,
    frequency,
    monetary,
    NTILE (4) OVER (
        ORDER BY
            recency DESC
    ) AS recency_quartile,
    NTILE (4) OVER (
        ORDER BY
            frequency
    ) AS frequency_quartile,
    NTILE (4) OVER (
        ORDER BY
            monetary
    ) AS monetary_quartile
FROM
    rfm_data
ORDER BY
    monetary DESC;

-- ======================
-- SHIPPING PERFORMANCE
-- ======================
/*
Analyzes delivery times by shipping mode
Identifies operational bottlenecks
 */
SELECT
    `Ship Mode`,
    AVG(DATEDIFF (`Ship Date`, `Order Date`)) AS avg_delivery_days,
    COUNT(
        CASE
            WHEN DATEDIFF (`Ship Date`, `Order Date`) > 7 THEN 1
        END
    ) AS late_shipments,
    ROUND(
        COUNT(
            CASE
                WHEN DATEDIFF (`Ship Date`, `Order Date`) > 7 THEN 1
            END
        ) * 100.0 / COUNT(*),
        2
    ) AS late_percentage
FROM
    superstore
GROUP BY
    `Ship Mode`
ORDER BY
    avg_delivery_days;