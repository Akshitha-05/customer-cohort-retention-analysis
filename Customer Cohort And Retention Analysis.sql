---create table--
CREATE TABLE online_retail (
    invoice_no    VARCHAR(20),
    stock_code    VARCHAR(20),
    description   TEXT,
    quantity      INT,
    invoice_date  TIMESTAMP,
    unit_price    NUMERIC(10,2),
    customer_id   VARCHAR(20),
    country       VARCHAR(50)
);

ALTER DATABASE retail_db_new SET datestyle = 'ISO, MDY';

----First — verify your import worked---
SELECT COUNT(*) FROM online_retail;

---Step 1 — Data exploration (understand your data)---
-- 1a. Overall profile
SELECT 
    COUNT(*)                        AS total_rows,
    COUNT(DISTINCT customer_id)     AS total_customers,
    MIN(invoice_date)               AS earliest_date,
    MAX(invoice_date)               AS latest_date,
    COUNT(DISTINCT country)         AS num_countries
FROM online_retail;

-- 1b. How many rows have no customer ID?
SELECT 
    COUNT(*)                                        AS total_rows,
    COUNT(customer_id)                              AS rows_with_customer,
    COUNT(*) - COUNT(customer_id)                   AS rows_missing_customer,
    ROUND(100.0 * (COUNT(*) - COUNT(customer_id))
          / COUNT(*), 2)                            AS pct_missing
FROM online_retail;


-- 1c. How many cancelled orders?
SELECT 
    COUNT(*)                        AS cancelled_rows
FROM online_retail
WHERE invoice_no LIKE 'C%';

-- 1d. Top 10 countries by revenue
SELECT 
    country,
    COUNT(DISTINCT customer_id)             AS customers,
    ROUND(SUM(quantity * unit_price), 2)    AS total_revenue
FROM online_retail
WHERE customer_id IS NOT NULL
  AND invoice_no NOT LIKE 'C%'
  AND quantity > 0
GROUP BY country
ORDER BY total_revenue DESC
LIMIT 10;

---Step 2 — Find each customer's first purchase month---
-- 2a. See what cohort_month looks like
SELECT 
    customer_id,
    DATE_TRUNC('month', MIN(invoice_date))  AS cohort_month
FROM online_retail
WHERE customer_id IS NOT NULL
  AND invoice_no NOT LIKE 'C%'
  AND quantity > 0
GROUP BY customer_id
ORDER BY cohort_month
LIMIT 20;

-- 2b. How many customers per cohort?
WITH first_purchase AS (
    SELECT 
        customer_id,
        DATE_TRUNC('month', MIN(invoice_date)) AS cohort_month
    FROM online_retail
    WHERE customer_id IS NOT NULL
      AND invoice_no NOT LIKE 'C%'
      AND quantity > 0
    GROUP BY customer_id
)
SELECT 
    cohort_month,
    COUNT(DISTINCT customer_id)  AS cohort_size
FROM first_purchase
GROUP BY cohort_month
ORDER BY cohort_month;

--Step 3 — Build cohort index--
-- 3. Assign cohort_index to every purchase
-- cohort_index 0 = first purchase month
-- cohort_index 1 = came back 1 month later, etc.
WITH first_purchase AS (
    SELECT 
        customer_id,
        DATE_TRUNC('month', MIN(invoice_date)) AS cohort_month
    FROM online_retail
    WHERE customer_id IS NOT NULL
      AND invoice_no NOT LIKE 'C%'
      AND quantity > 0
    GROUP BY customer_id
)
SELECT 
    f.customer_id,
    f.cohort_month,
    DATE_TRUNC('month', o.invoice_date)         AS purchase_month,
    (DATE_PART('year',  DATE_TRUNC('month', o.invoice_date))
     - DATE_PART('year',  f.cohort_month)) * 12
  + (DATE_PART('month', DATE_TRUNC('month', o.invoice_date))
     - DATE_PART('month', f.cohort_month))       AS cohort_index
FROM first_purchase f
JOIN online_retail o ON f.customer_id = o.customer_id
WHERE o.invoice_no NOT LIKE 'C%'
  AND o.quantity > 0
ORDER BY f.cohort_month, cohort_index
LIMIT 30;

---Step 4 — Retention counts (raw numbers)---
WITH first_purchase AS (
    SELECT 
        customer_id,
        DATE_TRUNC('month', MIN(invoice_date)) AS cohort_month
    FROM online_retail
    WHERE customer_id IS NOT NULL
      AND invoice_no NOT LIKE 'C%'
      AND quantity > 0
    GROUP BY customer_id
),
cohort_data AS (
    SELECT 
        f.customer_id,
        f.cohort_month,
        (DATE_PART('year',  DATE_TRUNC('month', o.invoice_date))
         - DATE_PART('year',  f.cohort_month)) * 12
      + (DATE_PART('month', DATE_TRUNC('month', o.invoice_date))
         - DATE_PART('month', f.cohort_month))  AS cohort_index
    FROM first_purchase f
    JOIN online_retail o ON f.customer_id = o.customer_id
    WHERE o.invoice_no NOT LIKE 'C%'
      AND o.quantity > 0
)
SELECT 
    cohort_month,
    cohort_index,
    COUNT(DISTINCT customer_id)  AS active_customers
FROM cohort_data
GROUP BY cohort_month, cohort_index
ORDER BY cohort_month, cohort_index;

--Step 5 — Final retention matrix ---
WITH first_purchase AS (
    SELECT 
        customer_id,
        DATE_TRUNC('month', MIN(invoice_date)) AS cohort_month
    FROM online_retail
    WHERE customer_id IS NOT NULL
      AND invoice_no NOT LIKE 'C%'
      AND quantity > 0
    GROUP BY customer_id
),
cohort_data AS (
    SELECT 
        f.customer_id,
        f.cohort_month,
        (DATE_PART('year',  DATE_TRUNC('month', o.invoice_date))
         - DATE_PART('year',  f.cohort_month)) * 12
      + (DATE_PART('month', DATE_TRUNC('month', o.invoice_date))
         - DATE_PART('month', f.cohort_month))  AS cohort_index
    FROM first_purchase f
    JOIN online_retail o ON f.customer_id = o.customer_id
    WHERE o.invoice_no NOT LIKE 'C%'
      AND o.quantity > 0
),
cohort_size AS (
    SELECT cohort_month,
           COUNT(DISTINCT customer_id) AS total_customers
    FROM cohort_data
    WHERE cohort_index = 0
    GROUP BY cohort_month
)
SELECT 
    cd.cohort_month,
    cs.total_customers                                                                                        AS cohort_size,
    ROUND(100.0 * COUNT(DISTINCT CASE WHEN cohort_index=0  THEN cd.customer_id END)/cs.total_customers,1)    AS month_0,
    ROUND(100.0 * COUNT(DISTINCT CASE WHEN cohort_index=1  THEN cd.customer_id END)/cs.total_customers,1)    AS month_1,
    ROUND(100.0 * COUNT(DISTINCT CASE WHEN cohort_index=2  THEN cd.customer_id END)/cs.total_customers,1)    AS month_2,
    ROUND(100.0 * COUNT(DISTINCT CASE WHEN cohort_index=3  THEN cd.customer_id END)/cs.total_customers,1)    AS month_3,
    ROUND(100.0 * COUNT(DISTINCT CASE WHEN cohort_index=4  THEN cd.customer_id END)/cs.total_customers,1)    AS month_4,
    ROUND(100.0 * COUNT(DISTINCT CASE WHEN cohort_index=5  THEN cd.customer_id END)/cs.total_customers,1)    AS month_5,
    ROUND(100.0 * COUNT(DISTINCT CASE WHEN cohort_index=6  THEN cd.customer_id END)/cs.total_customers,1)    AS month_6,
    ROUND(100.0 * COUNT(DISTINCT CASE WHEN cohort_index=7  THEN cd.customer_id END)/cs.total_customers,1)    AS month_7,
    ROUND(100.0 * COUNT(DISTINCT CASE WHEN cohort_index=8  THEN cd.customer_id END)/cs.total_customers,1)    AS month_8,
    ROUND(100.0 * COUNT(DISTINCT CASE WHEN cohort_index=9  THEN cd.customer_id END)/cs.total_customers,1)    AS month_9,
    ROUND(100.0 * COUNT(DISTINCT CASE WHEN cohort_index=10 THEN cd.customer_id END)/cs.total_customers,1)    AS month_10,
    ROUND(100.0 * COUNT(DISTINCT CASE WHEN cohort_index=11 THEN cd.customer_id END)/cs.total_customers,1)    AS month_11,
    ROUND(100.0 * COUNT(DISTINCT CASE WHEN cohort_index=12 THEN cd.customer_id END)/cs.total_customers,1)    AS month_12
FROM cohort_data cd
JOIN cohort_size cs ON cd.cohort_month = cs.cohort_month
GROUP BY cd.cohort_month, cs.total_customers
ORDER BY cd.cohort_month;

---Step 6 — Answer the project questions--
-- Which cohort retains best?
WITH first_purchase AS (
    SELECT customer_id,
        DATE_TRUNC('month', MIN(invoice_date)) AS cohort_month
    FROM online_retail
    WHERE customer_id IS NOT NULL
      AND invoice_no NOT LIKE 'C%'
      AND quantity > 0
    GROUP BY customer_id
),
cohort_data AS (
    SELECT f.customer_id, f.cohort_month,
        (DATE_PART('year',  DATE_TRUNC('month', o.invoice_date))
         - DATE_PART('year',  f.cohort_month)) * 12
      + (DATE_PART('month', DATE_TRUNC('month', o.invoice_date))
         - DATE_PART('month', f.cohort_month)) AS cohort_index
    FROM first_purchase f
    JOIN online_retail o ON f.customer_id = o.customer_id
    WHERE o.invoice_no NOT LIKE 'C%' AND o.quantity > 0
),
cohort_size AS (
    SELECT cohort_month, COUNT(DISTINCT customer_id) AS total
    FROM cohort_data WHERE cohort_index = 0 GROUP BY cohort_month
)
SELECT 
    cd.cohort_month,
    cs.total                                                                                     AS cohort_size,
    ROUND(100.0 * COUNT(DISTINCT CASE WHEN cohort_index=1 THEN cd.customer_id END)/cs.total,1)  AS month_1_pct,
    ROUND(100.0 * COUNT(DISTINCT CASE WHEN cohort_index=3 THEN cd.customer_id END)/cs.total,1)  AS month_3_pct,
    ROUND(100.0 * COUNT(DISTINCT CASE WHEN cohort_index=6 THEN cd.customer_id END)/cs.total,1)  AS month_6_pct
FROM cohort_data cd
JOIN cohort_size cs ON cd.cohort_month = cs.cohort_month
GROUP BY cd.cohort_month, cs.total
ORDER BY month_3_pct DESC NULLS LAST;

-- At what month do most customers churn?
WITH first_purchase AS (
    SELECT customer_id,
        DATE_TRUNC('month', MIN(invoice_date)) AS cohort_month
    FROM online_retail
    WHERE customer_id IS NOT NULL
      AND invoice_no NOT LIKE 'C%'
      AND quantity > 0
    GROUP BY customer_id
),
cohort_data AS (
    SELECT f.customer_id, f.cohort_month,
        (DATE_PART('year',  DATE_TRUNC('month', o.invoice_date))
         - DATE_PART('year',  f.cohort_month)) * 12
      + (DATE_PART('month', DATE_TRUNC('month', o.invoice_date))
         - DATE_PART('month', f.cohort_month)) AS cohort_index
    FROM first_purchase f
    JOIN online_retail o ON f.customer_id = o.customer_id
    WHERE o.invoice_no NOT LIKE 'C%' AND o.quantity > 0
),
cohort_size AS (
    SELECT cohort_month, COUNT(DISTINCT customer_id) AS total
    FROM cohort_data WHERE cohort_index = 0 GROUP BY cohort_month
),
retention_pct AS (
    SELECT cd.cohort_month, cd.cohort_index,
        ROUND(100.0 * COUNT(DISTINCT cd.customer_id) / cs.total, 1) AS retention
    FROM cohort_data cd
    JOIN cohort_size cs ON cd.cohort_month = cs.cohort_month
    GROUP BY cd.cohort_month, cd.cohort_index, cs.total
)
SELECT 
    cohort_index,
    ROUND(AVG(retention), 1)   AS avg_retention_pct
FROM retention_pct
WHERE cohort_index <= 12
GROUP BY cohort_index
ORDER BY cohort_index;