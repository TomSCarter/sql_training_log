WITH base_join AS(), -- rep_id, rep_name, year
aggregates AS(), -- active_customers, revenue
window AS(), -- revenue_rank
SELECT -- 1 row per support rep per calendar year. revenue_change_pct added. Round and order by
-- Decisions: RANK() for ranking, ties allowed. Previous for change means preceding calendar year, null if missing or 0
-- 4min

WITH base_join AS(
    SELECT
        c.SupportRepId AS rep_id,
        e.FirstName || ' ' || e.LastName AS rep_name,
        strftime('%Y', i.InvoiceDate) AS year,
        i.Total,
        c.CustomerId
    FROM
        Invoice i
    INNER JOIN Customer c USING(CustomerId)
    INNER JOIN Employee e ON e.EmployeeId = c.SupportRepId
    ),
aggregates AS(
    SELECT
        rep_id,
        rep_name,
        year,
        SUM(Total) AS revenue,
        COUNT(DISTINCT CustomerId) AS active_customers
    FROM
        base_join
    GROUP BY
        rep_id,
        rep_name, 
        year

),
window AS(
    SELECT
        rep_id,
        rep_name,
        year,
        revenue,
        active_customers,
        RANK() OVER(PARTITION BY year ORDER BY revenue) AS revenue_rank,
        revenue - LAG(revenue) OVER(PARTITION BY rep_id ORDER BY year) AS revenue_diff,
        year - LAG(year) OVER(PARTITION BY rep_id ORDER BY year) AS year_diff
    FROM
        aggregates     

)
SELECT
        rep_id,
        rep_name,
        year,
        ROUND(revenue, 2) AS revenue,
        active_customers,
        revenue_rank,
        CASE WHEN year_diff <> 1 THEN NULL ELSE ROUND((100 * revenue_diff/revenue), 2) END AS revenue_change_pct
FROM
    window
ORDER BY
    year,
    revenue_rank,
    rep_id;
-- 21 min
-- Ranking is reversed. Percentage uses wrong denominator. Final columns wrong order. Missing nullif

WITH base_join AS(
    SELECT
        c.SupportRepId AS rep_id,
        e.FirstName || ' ' || e.LastName AS rep_name,
        strftime('%Y', i.InvoiceDate) AS year,
        i.Total,
        c.CustomerId
    FROM
        Invoice i
    INNER JOIN Customer c USING(CustomerId)
    INNER JOIN Employee e ON e.EmployeeId = c.SupportRepId
    ),
aggregates AS(
    SELECT
        rep_id,
        rep_name,
        year,
        SUM(Total) AS revenue,
        COUNT(DISTINCT CustomerId) AS active_customers
    FROM
        base_join
    GROUP BY
        rep_id,
        rep_name, 
        year

),
window AS(
    SELECT
        rep_id,
        rep_name,
        year,
        revenue,
        active_customers,
        RANK() OVER(PARTITION BY year ORDER BY revenue DESC) AS revenue_rank,
        LAG(revenue) OVER(PARTITION BY rep_id ORDER BY year) AS previous_revenue,
        year - LAG(year) OVER(PARTITION BY rep_id ORDER BY year) AS year_diff
    FROM
        aggregates     

)
SELECT
        rep_id,
        rep_name,
        year,
        active_customers,
        ROUND(revenue, 2) AS revenue,
        revenue_rank,
        CASE 
            WHEN year_diff = 1 THEN ROUND((100 * (revenue - previous_revenue)/ NULLIF(previous_revenue, 0)), 2) 
            END AS revenue_change_pct
FROM
    window
ORDER BY
    year,
    revenue_rank,
    rep_id;




