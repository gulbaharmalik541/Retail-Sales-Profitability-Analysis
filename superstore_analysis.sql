CREATE DATABASE IF NOT EXISTS superstore_db;
USE superstore_db;

SELECT COUNT(*) FROM retail_orders;

-- ================================================================
-- PROJECT: End-to-End Retail Sales & Profitability Analysis
-- DATABASE: MySQL 8.0+
-- AUTHOR: Gulbahar
-- PURPOSE: Business intelligence querying, discount margin analysis, 
--          customer ranking, and window functions.
-- ================================================================

USE superstore_db;

-- ----------------------------------------------------------------
-- 1. VERIFY DATA IMPORT INTEGRITY
-- ----------------------------------------------------------------
SELECT 
    COUNT(*) AS total_rows,
    COUNT(DISTINCT `Order ID`) AS total_orders,
    COUNT(DISTINCT `Customer ID`) AS total_customers,
    ROUND(SUM(Sales), 2) AS total_gross_sales,
    ROUND(SUM(Profit), 2) AS total_net_profit,
    ROUND((SUM(Profit) / SUM(Sales)) * 100, 2) AS overall_profit_margin_pct
FROM retail_orders;


-- ----------------------------------------------------------------
-- 2. IDENTIFY LOSS-LEADERS (Sub-Categories Destroying Margins)
-- SQL Concept: GROUP BY, HAVING, ORDER BY
-- Business Value: Pinpoints lines operating at an aggregate net loss.
-- ----------------------------------------------------------------
SELECT 
    `Sub-Category`,
    COUNT(`Order ID`) AS items_sold,
    ROUND(SUM(Sales), 2) AS total_sales,
    ROUND(SUM(Profit), 2) AS net_profit,
    ROUND((SUM(Profit) / SUM(Sales)) * 100, 2) AS profit_margin_pct
FROM retail_orders
GROUP BY `Sub-Category`
HAVING net_profit < 0
ORDER BY net_profit ASC;


-- ----------------------------------------------------------------
-- 3. THE DISCOUNT MARGIN EROSION ANALYSIS
-- SQL Concept: CASE WHEN, Aggregate Profit Margin calculation
-- Business Value: Evaluates how margin drops as discount brackets rise.
-- ----------------------------------------------------------------
SELECT 
    CASE 
        WHEN Discount = 0 THEN '0% (No Discount)'
        WHEN Discount <= 0.20 THEN '1% - 20%'
        WHEN Discount <= 0.40 THEN '21% - 40%'
        WHEN Discount <= 0.60 THEN '41% - 60%'
        ELSE '61%+'
    END AS discount_tier,
    COUNT(DISTINCT `Order ID`) AS total_orders,
    ROUND(SUM(Sales), 2) AS total_sales,
    ROUND(SUM(Profit), 2) AS total_profit,
    ROUND((SUM(Profit) / SUM(Sales)) * 100, 2) AS aggregate_margin_pct
FROM retail_orders
GROUP BY discount_tier
ORDER BY total_profit DESC;


-- ----------------------------------------------------------------
-- 4. MONTHLY REVENUE & CUMULATIVE RUNNING TOTAL
-- SQL Concept: Common Table Expressions (CTE), Window Function (SUM() OVER)
-- Business Value: Shows growth momentum and cumulative sales progression.
-- ----------------------------------------------------------------
WITH MonthlySummary AS (
    SELECT 
        `Order Month` AS order_month,
        ROUND(SUM(Sales), 2) AS monthly_sales,
        ROUND(SUM(Profit), 2) AS monthly_profit
    FROM retail_orders
    GROUP BY `Order Month`
)
SELECT 
    order_month,
    monthly_sales,
    monthly_profit,
    ROUND(SUM(monthly_sales) OVER (ORDER BY order_month), 2) AS cumulative_running_sales
FROM MonthlySummary
ORDER BY order_month ASC;


-- ----------------------------------------------------------------
-- 5. TOP 3 CUSTOMERS PER REGION (RANKING)
-- SQL Concept: CTE, Window Function (DENSE_RANK() OVER PARTITION BY)
-- Business Value: Identifies VIP accounts in each geographic territory.
-- ----------------------------------------------------------------
WITH RegionalCustomerSpend AS (
    SELECT 
        Region,
        `Customer Name`,
        ROUND(SUM(Sales), 2) AS total_spend,
        DENSE_RANK() OVER (
            PARTITION BY Region 
            ORDER BY SUM(Sales) DESC
        ) AS spending_rank
    FROM retail_orders
    GROUP BY Region, `Customer Name`
)
SELECT 
    Region,
    spending_rank,
    `Customer Name`,
    total_spend
FROM RegionalCustomerSpend
WHERE spending_rank <= 3
ORDER BY Region, spending_rank;


-- ----------------------------------------------------------------
-- 6. RFM SEGMENT REVENUE CONTRIBUTION & REVENUE SHARE
-- SQL Concept: Window Function for calculating % of Total inside SQL
-- Business Value: Validates customer concentration (e.g. Champions revenue %).
-- ----------------------------------------------------------------
SELECT 
    `RFM Segment`,
    COUNT(DISTINCT `Customer ID`) AS total_customers,
    ROUND(SUM(Sales), 2) AS segment_revenue,
    ROUND(
        (SUM(Sales) / SUM(SUM(Sales)) OVER ()) * 100, 
        2
    ) AS revenue_share_pct
FROM retail_orders
GROUP BY `RFM Segment`
ORDER BY segment_revenue DESC;


-- ----------------------------------------------------------------
-- 7. SHIPPING DURATION PERFORMANCE & SLA BREACH (> 4 DAYS)
-- SQL Concept: Conditional Aggregation (SUM(CASE WHEN ...))
-- Business Value: Analyzes fulfillment speed and delivery reliability.
-- ----------------------------------------------------------------
SELECT 
    `Ship Mode`,
    COUNT(`Order ID`) AS total_shipments,
    ROUND(AVG(`Shipping Days`), 1) AS avg_shipping_days,
    SUM(CASE WHEN `Shipping Days` > 4 THEN 1 ELSE 0 END) AS delayed_orders,
    ROUND(
        (SUM(CASE WHEN `Shipping Days` > 4 THEN 1 ELSE 0 END) / COUNT(`Order ID`)) * 100, 
        2
    ) AS delay_rate_pct
FROM retail_orders
GROUP BY `Ship Mode`
ORDER BY avg_shipping_days ASC;