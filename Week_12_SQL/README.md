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