WITH monthly_totals AS (SELECT 
    CustomerId,
    strftime('%Y-%m', InvoiceDate) AS year_month,
    SUM(Total) AS month_spend
FROM
    Invoice
GROUP BY
    CustomerId,
    strftime('%Y-%m', InvoiceDate)
),
 cte AS (SELECT 
    CustomerId AS customer_id,
    FirstName || ' ' || LastName AS customer_name,
    year_month,
    ROUND(month_spend, 2) AS month_spend,
    ROUND(AVG(month_spend) OVER(PARTITION BY CustomerId ORDER BY year_month), 2) AS running_mean,
    ROUND(month_spend - AVG(month_spend) OVER(PARTITION BY CustomerId ORDER BY year_month), 2) AS delta_vs_mean,
    RANK() OVER(PARTITION BY CustomerId ORDER BY month_spend) AS is_peak
FROM monthly_totals
INNER JOIN Customer USING(CustomerId)
ORDER BY CustomerId, year_month
)

SELECT 
    customer_id,
    customer_name,
    year_month,
    month_spend,
    running_mean,
    delta_vs_mean,
    COALESCE((SELECT 1 FROM cte WHERE is_peak = 1), 0) AS is_peak
FROM cte;









