-- Week 11, Day 4: LAG/LEAD and Chronological Offsets
-- Focus: period-over-period changes, gaps between events, comparing across several rows, and the main LAG/LEAD trap: LAG gives you the previous row, not the previous date. If the timeline has gaps, those are different things.
-- LAG(column1, offset, default) OVER(PARTITION BY column3 ORDER BY column2). offset is # rows to go back, default is what to do with initial nulls

-- Block 1: Basic period-over-period change
-- Local: monthly revenue across the whole store, with the change from the previous month both as an absolute amount and as a percentage. Aggregate to monthly grain first (yesterday's lesson). Decide what the first month should show, and make sure the percentage calculation can't divide by zero or produce a misleading value.
-- Grain: 1 row per month with months revenue and change from previous (amount and percentage)
WITH monthly AS(
    SELECT
        strftime('%m',InvoiceDate) AS shop_month,
        SUM(Total) AS month_total
    FROM
        Invoice
    GROUP BY strftime('%m',InvoiceDate)
)
SELECT
    shop_month,
    month_total,
    ROUND(COALESCE(month_total - LAG(month_total) OVER(ORDER BY shop_month), 0), 2) AS abs_change,
    ROUND(COALESCE(100 * (month_total - LAG(month_total) OVER(ORDER BY shop_month)) / month_total, 0), 2) AS percent_change
FROM
    monthly
--12 min. But this combines months from several years
-- Use '%Y-%m'. Percentage divided by wrong month. Use NULLIF(..,0) to protect against dividing by 0. COALESCE probably not needed, null makes more sense for first row
WITH monthly AS(
    SELECT
        strftime('%Y-%m',InvoiceDate) AS shop_month,
        SUM(Total) AS month_total
    FROM
        Invoice
    GROUP BY strftime('%Y-%m',InvoiceDate)
)
SELECT
    shop_month,
    month_total,
    ROUND(month_total - LAG(month_total) OVER(ORDER BY shop_month), 2) AS abs_change,
    ROUND(100 * (month_total - LAG(month_total) OVER(ORDER BY shop_month)) / NULLIF(LAG(month_total) OVER(ORDER BY shop_month), 0), 2) AS percent_change
FROM
    monthly
ORDER BY shop_month
-- Transfer: LeetCode 197, Rising Temperature. Read the data carefully and think about whether "the previous row" and "yesterday" are always the same thing.
-- Grain: List of ids
WITH cte AS(
    SELECT
        id,
        temperature - LAG(temperature) OVER(ORDER BY recordDate) AS temp_diff,
        recordDate - LAG(recordDate) OVER(ORDER BY recordDate) AS date_diff
    FROM Weather
)
SELECT
    id
FROM 
    cte
WHERE temp_diff > 0 AND date_diff = 1
-- 7 min (4 min before I had to add date_diff)
-- Common alternative is a self-join matching date to a date 1 day earlier

-- Block 2: Offsets within partitions
-- Local: for each customer, the number of days between each invoice and their previous one. Then build on it to get each customer's average gap between purchases. In SQLite, julianday() turns dates into numbers you can subtract. Decide how each customer's first invoice should be handled in both the gap column and the average.
SELECT
    CustomerId,
    AVG(InvoiceDate - LAG(InvoiceDate) OVER(PARTITION BY CustomerId ORDER BY InvoiceDate)) AS avg_gap
FROM Invoice
GROUP BY CustomerId
-- 7min doesnt run. You cant put a window inside an aggregation as GROUP BY runs before SELECT(windows)
WITH gaps AS(
    SELECT
        CustomerId,
        julianday(InvoiceDate) - julianday(LAG(InvoiceDate) OVER(PARTITION BY CustomerId ORDER BY InvoiceDate)) AS inv_gap
    FROM Invoice
)
SELECT
    CustomerId,
    AVG(inv_gap) as avg_gap
FROM gaps
GROUP BY CustomerId
-- Further 4:30. First invoices gap is null, which is good as it doesnt get used in average.

-- Transfer: LeetCode 550, Game Play Analysis IV. This is a grain test as well as an offset problem: the final output is a single number, so work out what each intermediate layer represents.
-- Grain: A single value count of players scaled to a percentage. Starting from 1 row per player login
-- Write your PostgreSQL query statement below
WITH first_l AS(
    SELECT
        player_id,
        MIN(event_date) AS first_login
    FROM
        Activity
    GROUP BY player_id
),
second AS (
    SELECT
    player_id,
    date(a.event_date) - date(f.first_login) AS days_since_login
FROM
    Activity a
INNER JOIN first_l f USING(player_id)
)
SELECT
    ROUND(COUNT(DISTINCT s.player_id) / (SELECT COUNT(*) FROM Activity a GROUP BY a.PlayerId), 2) AS fraction
FROM second s
WHERE days_since_login = 1
-- 16min but doesnt like final calculation. Typo in final select (PlayerId), subquery returns multiple values

WITH first_l AS(
    SELECT
        player_id,
        MIN(event_date) AS first_login
    FROM
        Activity
    GROUP BY player_id
),
second AS (
    SELECT
    player_id,
    date(a.event_date) - date(f.first_login) AS days_since_login
FROM
    Activity a
INNER JOIN first_l f USING(player_id)
)
SELECT
    ROUND(CAST(COUNT(DISTINCT s.player_id) AS numeric) / (SELECT COUNT(*) FROM first_l), 2) AS fraction
FROM second s
WHERE days_since_login = 1
-- Needed some help with Postgres quirks. Dividing 2 integers gives 0 not a fraction, so 1 must be cast to numeric. Subquery must have its own brackets
-- cast with CAST(... AS numeric) or ...::numeric


-- Block 3: Comparing more than one row back
-- Transfer only: LeetCode 180, Consecutive Numbers. Think about how many offsets you need, and in which directions. Also check whether the output needs DISTINCT.
-- Write your PostgreSQL query statement below
WITH counts AS(
    SELECT
        id,
        num,
        LAG(num, 1) OVER(ORDER BY id) AS prev,
        LAG(num, 2) OVER(ORDER BY id) AS two_prev
    FROM Logs
)
SELECT
    DISTINCT num AS ConsecutiveNums
FROM counts
WHERE num = prev AND prev = two_prev
--4:45 min. easy
-- If id contained gaps, then we would need to calculate the offsets beween ids

-- Block 4: The timeline-gap trap (local only)
-- Monthly revenue per billing country, with each month compared to that country's previous month. Then look at the output carefully: do some countries have months with no sales at all? If so, what is LAG actually comparing against for the month after a gap? Write in your log what's wrong and why.
-- Grain: 1 row per month per country
WITH monthly_rev AS (
    SELECT
        ROUND(SUM(Total), 2) AS monthly_revenue,
        BillingCountry,
        strftime('%Y-%m', InvoiceDate) AS year_month
    FROM Invoice
    GROUP BY BillingCountry, strftime('%Y-%m', InvoiceDate)
)
SELECT
    BillingCountry,
    year_month,
    monthly_revenue,
    LAG(monthly_revenue) OVER(PARTITION BY BillingCountry ORDER BY year_month) AS prev_recorded_month_revenue
FROM monthly_rev
ORDER BY BillingCountry, year_month
-- 8 min. As expected prev_month_revenue compares to previous value not previous month (if there is a gap)

-- Stretch (only if you have time): fix it by building a complete calendar of months (a "date spine") with a recursive CTE, then LEFT JOIN the revenue onto it so that missing months appear as zero. This is a standard analytics-engineering pattern and comes up again in dbt.
WITH RECURSIVE calendar AS(
    SELECT date(MIN(InvoiceDate),  'start of month') AS month_start
    FROM Invoice
    UNION ALL
    SELECT date(month_start, '+1 month')
    FROM calendar
    WHERE date(month_start, '+1 month') <= (SELECT MAX(InvoiceDate) FROM Invoice)
),
countrys AS (
    SELECT
    DISTINCT BillingCountry AS BillingCountry,
    strftime('%Y-%m', month_start) AS months
FROM 
    calendar
CROSS JOIN Invoice
),
monthly_rev AS (
    SELECT
        ROUND(SUM(Total), 2) AS monthly_revenue,
        BillingCountry,
        strftime('%Y-%m', InvoiceDate) AS year_month
    FROM Invoice
    GROUP BY BillingCountry, strftime('%Y-%m', InvoiceDate)
),
joined AS(
    SELECT
    c.months AS year_month,
    c.BillingCountry,
    COALESCE(m.monthly_revenue, 0) AS monthly_revenue
FROM countrys c 
LEFT JOIN monthly_rev m ON c.months = m.year_month AND c.BillingCountry = m.BillingCountry
)
SELECT
    BillingCountry,
    year_month,
    monthly_revenue,
    LAG(monthly_revenue) OVER(PARTITION BY BillingCountry ORDER BY year_month) AS prev_month_revenue
FROM joined
ORDER BY BillingCountry, year_month
-- Reduce before joining, CTE cross joins entire Invoice table with Calendar, select distinct countries first