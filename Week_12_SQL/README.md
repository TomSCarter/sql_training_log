# Day 1

### Problem A: customers who share a city
```
Setup data (paste into any SQL sandbox, such as DB Fiddle or SQLite):
```
```sql
CREATE TABLE customers (
    customer_id INT PRIMARY KEY,
    name        VARCHAR(50),
    city        VARCHAR(50)
);

INSERT INTO customers VALUES
(1, 'Asha',  'London'),
(2, 'Ben',   'Leeds'),
(3, 'Chloe', 'London'),
(4, 'Dev',   'Manchester'),
(5, 'Ella',  'Leeds'),
(6, 'Femi',  'London'),
(7, 'Grace', NULL),
(8, 'Hari',  NULL),
(9, 'Isla',  'Bristol');
```
```
**Brief:** Return every pair of distinct customers who live in the same city. Output columns are `city, customer_id_1, name_1, customer_id_2, name_2`.

**Rules:**
1. No self-pairs: Asha must not be paired with Asha.
2. No duplicate pairs: (Asha, Chloe) and (Chloe, Asha) are the same pair, so only one should appear.
3. Customers with an unknown city should not be paired with each other.
4. Order by city, then by the first ID, then by the second ID.

**Expected output (4 rows):**

| city | customer_id_1 | name_1 | customer_id_2 | name_2 |
|---|---|---|---|---|
| Leeds | 2 | Ben | 5 | Ella |
| London | 1 | Asha | 3 | Chloe |
| London | 1 | Asha | 6 | Femi |
| London | 3 | Chloe | 6 | Femi |

**Process:** Write the skeleton plan first, before any SQL: a grain comment for the output ("one row per ___") and a DECISIONS line covering how you'll handle rules 1–3. Then write the query.

**Questions to answer after you pass:**
1. London has 3 customers and produced 3 pairs. If a city had *n* customers, how many rows should it produce? Turn that into a sanity check you could run against your output.
2. Did you write anything specific for rule 3, or did it happen automatically? Explain why.
3. Suppose one row had been entered as `'london '`, with a lowercase *l* and a trailing space. What would your query do with it, and what would you change?
```


My answer:

```sql
-- Join on city matching id (id less than id to avoid the duplicates). check nulls and self pairs are lost in join
-- Order
-- 1 row per distinct pair of customers in a city
SELECT
    a.city,
    a.customer_id AS customer_id_1,
    a.name AS name_1,
    b.customer_id AS customer_id_2,
    b.name AS name_2
FROM customers AS a
INNER JOIN customers AS b ON a.city = b.city AND a.customer_id < b.customer_id
ORDER BY a.city, a.customer_id, b.customer_id;

-- n customers gives n(n-1)/2 rows
-- null = null is unknown, only true is kept (not null=null is still unknown)
-- 'london ' would need INITCAP() (postgres) or standardise with UPPER and TRIM()
```
- 15 min. Fail, had it but including duplicate pairs and joining on name rather than id
- Needed some hints to realise that id < id was the way to remove duplicates (I had id <> id)

### Problem B: LeetCode 1731
- 10 min. Pass. Forgot to add one value to groupby (but error caught it)

```sql
-- 1 row per manager from 1 row per employee
-- self join on reports_to = id, nulls are excluded
-- group by b.id count rows, avg age rounded, order by b.id

WITH joined AS (
    SELECT
        b.employee_id AS employee_id,
        b.name AS name,
        a.name AS report_name,
        a.age AS report_age
    FROM Employees a
    INNER JOIN Employees b ON b.employee_id = a.reports_to
)
SELECT
    employee_id,
    name,
    COUNT(*) AS reports_count,
    ROUND(AVG(report_age), 0) AS average_age
FROM joined
GROUP BY employee_id, name
ORDER BY employee_id;
```

# Day 2

Metric table problems 
- One row per entity x time period (e.g. customer x month, genre x month, rep x year) with a few base measures and columns derived from them
- Common in reporting work
- Can be split into a 4 layer template
    1. Base: join the facts to whatever attributes you need, at the finest grain required. 
        (Grain: one row per invoice or invoice line.)
    2. Aggregate: GROUP BY entity and period to get the base measures: sums, counts, distinct counts. 
        (Grain: entity × period. This is the report's grain.)
    3. Windows: every column that compares rows: running totals, shares, ranks, LAG values. 
        (Same grain, more columns.)
    4. Final: anything that uses a window result: flags, CASE logic, NULL rules, rounding, ordering. 

My initial answer:

```sql
--PLAN:
WITH base_join AS(), -- rep_id, rep_name, year
aggregates AS(), -- active_customers, revenue
window AS(), -- revenue_rank
SELECT -- 1 row per support rep per calendar year. revenue_change_pct added. Round and order by
-- Decisions: RANK() for ranking, ties allowed. Previous for change means preceding calendar year, null if missing or 0
-- 4min
```

```sql
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
```
```sql
-- Corrected answer
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
```
# Day 3

- Leetcode 1193
```sql
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
```

- Had it in 15min except could not work out how to get the date as year-month in Postgresql. Wasted lots of time looking at EXTRACT and DATE_TRUNC. Should have searched for 'postgres version of strfdate(%Y-%m)'
```sql
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
```

- Leetcode 1581

```sql
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
```
- Got all except COALESCE in 10 min then was interrupted, would have got it in 15min I am sure.

# Day 4

- Cold repeat of Leetcode 1321 Restaurant Growth (that was so poorly written)

```sql
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
```

- Got this in 15min but could not work out why the final moving average was wrong
- Turns out the final moving average should be per day not per customer (even though the description says 'moving average of how much the customer paid in a seven days window'). So average the daily total. Was wondering if averaging twice was wrong but hadn't clocked why

```sql

-- Base: No joins needs
-- Agg: Sum amount group by date and avg amount by date
-- Windows: Moving average (RANGE INTERVAL '6 days'), date_diff (date - lag(date))
-- Final: 1 row per day with total amount and 7 day per customer moving average

WITH aggs AS(SELECT
    visited_on,
    SUM(amount) AS amount
FROM Customer
GROUP BY
    visited_on),
 wins AS(SELECT
    visited_on,
    SUM(amount) OVER(ORDER BY visited_on RANGE INTERVAL '6 days' PRECEDING) AS amount,
    AVG(amount) OVER(ORDER BY visited_on RANGE INTERVAL '6 days' PRECEDING) AS average_amount,
    visited_on - LAG(visited_on, 6) OVER(ORDER BY visited_on) AS date_diff
FROM aggs)
SELECT
    visited_on,
    amount,
    ROUND(average_amount,2) AS average_amount
FROM wins
WHERE date_diff IS NOT NULL
ORDER BY visited_on
```

# Day 5


Exam 1 redo, the brief:

## Week 11 Exam: Customer Monthly Spend Profile

**Database:** Chinook (SQLite)
**Target:** under 12 minutes. **Hard stop:** 25 minutes.
**Allowed:** nothing but the editor and the database.

### Task

For each customer, show their spending month by month, how each month compares with their running average up to that point, and which month was their peak.

### Output grain

One row per customer per calendar month **in which that customer has at least one invoice.** Months with no invoices do *not* need to appear.

### Output columns, in this order

| Column | Definition |
|---|---|
| `customer_id` | The customer's ID. |
| `customer_name` | First name and last name, separated by a single space. |
| `year_month` | The calendar month, formatted `YYYY-MM`. |
| `month_spend` | The sum of that customer's invoice totals in that month. |
| `running_mean` | The average of that customer's `month_spend` values over all their months **up to and including this one,** in chronological order. |
| `delta_vs_mean` | `month_spend` minus `running_mean`. |
| `is_peak` | `1` for the customer's single highest-`month_spend` month, `0` for every other month. If two or more months tie for highest, the **earliest** of those months is the peak. Each customer has exactly one peak month. |

### Formatting

- Round `month_spend`, `running_mean` and `delta_vs_mean` to 2 decimal places, in the final output only.
- Sort by `customer_id`, then `year_month`.


My answer:

```sql

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
```

- Pass on correctness but too slow. Lost perhaps 5min on trying to remember TO_CHAR then realising this is SQLite and trying to remember strftime. Also had to stop in the middle for a bit. Still can't quite imagine doing this in 12 min.

- The first 2 and second 2 parts could be combined into 1 CTE and a final query but it would be less readable
```sql
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
    ROUND(AVG(month_spend) OVER(PARTITION BY customerid ORDER BY year_month ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW), 2) AS running_mean,
   ROUND(month_spend -  AVG(month_spend) OVER(PARTITION BY customerid ORDER BY year_month ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW), 2) AS delta_vs_mean,
    CASE WHEN ROW_NUMBER() OVER(PARTITION BY customerid ORDER BY month_spend DESC, year_month) = 1 THEN 1 ELSE 0 END AS is_peak
FROM base
ORDER BY customer_id, year_month
```
