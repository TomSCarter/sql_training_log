
-- Base: Join Invoice and Customer, extract year_month
-- Agg: SUM(Total), GROUP BY customer_id and year_month
-- Windows: AVG window
-- CASE WHEN flag
-- Final grain: 1 row per customer x month. With comparison to running average and flag for peak
--4min

WITH base AS(SELECT
    i.customerid,
    c.FirstName || ' ' || c.LastName AS customer_name,
    strftime('%Y-%m', i.InvoiceDate) AS year_month,
    i.Total
FROM
    Invoice i
INNER JOIN
    Customer c USING (customerid)),
    -- 12min wrote for Postgres to start
agg AS(SELECT
    customerid,
    customer_name,
    year_month,
    SUM(Total) AS month_spend
FROM base
GROUP BY
    customerid,
    customer_name,
    year_month),

winds AS(SELECT
    customerid,
    customer_name,
    year_month,
    month_spend,
    AVG(month_spend) OVER(PARTITION BY customerid ORDER BY year_month ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS running_mean,
    ROW_NUMBER() OVER(PARTITION BY customerid ORDER BY month_spend DESC, year_month) AS rowrank
FROM agg)

SELECT
    customerid AS customer_id,
    customer_name,
    year_month,
    ROUND(month_spend, 2) AS month_spend,
    ROUND(running_mean, 2) AS running_mean,
   ROUND(month_spend - running_mean, 2) AS delta_vs_mean,
    CASE WHEN rowrank = 1 THEN 1 ELSE 0 END AS is_peak
FROM winds
ORDER BY customer_id, year_month
-- 23min. Whether there should be some COALESCEs in there



WITH base AS(SELECT
    i.customerid,
    c.FirstName || ' ' || c.LastName AS customer_name,
    strftime('%Y-%m', i.InvoiceDate) AS year_month,
    SUM(i.Total) AS month_spend
FROM
    Invoice i
INNER JOIN
    Customer c USING (customerid)
GROUP BY
    customerid,
    customer_name,
    year_month)

SELECT
    customerid AS customer_id,
    customer_name,
    year_month,
    ROUND(month_spend, 2) AS month_spend,
    ROUND(AVG(month_spend) OVER w, 2) AS running_mean,
   ROUND(month_spend -  AVG(month_spend) OVER w, 2) AS delta_vs_mean,
    CASE WHEN ROW_NUMBER() OVER(PARTITION BY customerid ORDER BY month_spend DESC, year_month) = 1 THEN 1 ELSE 0 END AS is_peak
FROM base
WINDOW w AS (PARTITION BY customerid ORDER BY year_month ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)
ORDER BY customer_id, year_month

