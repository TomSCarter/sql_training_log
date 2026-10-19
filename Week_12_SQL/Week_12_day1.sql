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

--PROBLEM 2
-- 1 row per manager from 1 row per employee
-- self join on reports_to = id, nulls are excluded
-- group by b.id count rows, avg age rounded, order by b.id

WITH joined AS (SELECT
    b.employee_id AS employee_id,
    b.name AS name,
    a.name AS report_name,
    a.age AS report_age
FROM Employees a
INNER JOIN Employees b ON b.employee_id = a.reports_to)
SELECT 
    employee_id,
    name,
    COUNT(*) AS reports_count,
    ROUND(AVG(report_age),0) AS average_age
FROM joined
GROUP BY employee_id, name
ORDER BY employee_id