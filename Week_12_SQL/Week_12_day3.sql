-- Leetcode 1193
SELECT
    CONCAT(EXTRACT(YEAR FROM trans_date), '-', EXTRACT(MONTH FROM trans_date)) AS month,
    country,
    COUNT(id) AS trans_count,
    COUNT(CASE WHEN state = 'approved' THEN id END) AS approved_count,
    SUM(amount) AS trans_total_amount,
    SUM(CASE WHEN state = 'approved' THEN amount END) AS approved_total_amount
FROM
    Transactions
GROUP BY
    country,
    CONCAT(EXTRACT(YEAR FROM trans_date), '-', EXTRACT(MONTH FROM trans_date))


-- Had it in 15min except could not work out how to get the date as year-month in Postgresql. Wasted lots of time looking at EXTRACT and DATE_TRUNC. Should have searched for 'postgres version of strfdate(%Y-%m)'

SELECT
    TO_CHAR(trans_date, 'YYYY-MM') AS month,
    country,
    COUNT(id) AS trans_count,
    COUNT(CASE WHEN state = 'approved' THEN id END) AS approved_count,
   COALESCE(SUM(amount), 0) AS trans_total_amount,
    COALESCE(SUM(CASE WHEN state = 'approved' THEN amount END), 0) AS approved_total_amount
FROM
    Transactions
GROUP BY
    country,
    month


    
-- Leetcode 1581

-- Left join where transactionid is null
-- group by customer_id
-- Final grain: 1 row per customer with a count

SELECT
    customer_id,
    COUNT(COALESCE(t.visit_id, 1)) AS count_no_trans
FROM
    Visits v
LEFT JOIN Transactions t ON v.visit_id = t.visit_id

WHERE t.visit_id IS NULL
GROUP BY
    customer_id