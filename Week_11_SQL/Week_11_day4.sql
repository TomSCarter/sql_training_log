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


-- Block 2: Offsets within partitions
-- Local: for each customer, the number of days between each invoice and their previous one. Then build on it to get each customer's average gap between purchases. In SQLite, julianday() turns dates into numbers you can subtract. Decide how each customer's first invoice should be handled in both the gap column and the average.

-- Transfer: LeetCode 550, Game Play Analysis IV. This is a grain test as well as an offset problem: the final output is a single number, so work out what each intermediate layer represents.


-- Block 3: Comparing more than one row back
-- Transfer only: LeetCode 180, Consecutive Numbers. Think about how many offsets you need, and in which directions. Also check whether the output needs DISTINCT.


-- Block 4: The timeline-gap trap (local only)

-- Monthly revenue per billing country, with each month compared to that country's previous month. Then look at the output carefully: do some countries have months with no sales at all? If so, what is LAG actually comparing against for the month after a gap? Write in your log what's wrong and why.

-- Stretch (only if you have time): fix it by building a complete calendar of months (a "date spine") with a recursive CTE, then LEFT JOIN the revenue onto it so that missing months appear as zero. This is a standard analytics-engineering pattern and comes up again in dbt.