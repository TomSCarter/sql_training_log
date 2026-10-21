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
