--Leetcode 1321 cold repeat


-- Base: No joins needs
-- Agg: Sum amount group by date and avg amount by date
-- Windows: Moving average (RANGE INTERVAL '6 days'), date_diff (date - lag(date))
-- Final: 1 row per day with total amount and 7 day per customer moving average

WITH aggs AS(SELECT
    visited_on,
    SUM(amount) AS amount,
    AVG(amount) AS day_average
FROM Customer
GROUP BY
    visited_on),
 wins AS(SELECT
    visited_on,
    SUM(amount) OVER(ORDER BY visited_on RANGE INTERVAL '6 days' PRECEDING) AS amount,
    AVG(day_average) OVER(ORDER BY visited_on RANGE INTERVAL '6 days' PRECEDING) AS average_amount,
    visited_on - LAG(visited_on, 6) OVER(ORDER BY visited_on) AS date_diff
FROM aggs)
SELECT
    visited_on,
    amount,
    ROUND(average_amount,2) AS average_amount
FROM wins
WHERE date_diff IS NOT NULL
ORDER BY visited_on

-- Got this in 15min but could not work out why the final moving average was wrong