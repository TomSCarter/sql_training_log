-- Week 11, Day 5: Multi-Tier CTEs and Exam Preparation

-- Focus: refactoring tangled nested queries into clean, linear CTE chains; building multi-step pipelines from scratch; and getting ready for this weekend's timed exam.
-- CTEs make queries clearer, not faster. Materialisation behaviour depends on the engine

-- Block 1: Refactoring a nested query
-- Here's a deliberately messy query to work with. It finds customers whose total spend is above the average for their country, along with their support rep. It runs correctly; your job is to make it maintainable.
SELECT
    c.FirstName || ' ' || c.LastName AS customer_name,
    s.Country,
    s.total_spend,
    e.FirstName || ' ' || e.LastName AS rep_name
FROM (
    SELECT cu.CustomerId, cu.Country, SUM(i.Total) AS total_spend
    FROM Invoice AS i
    JOIN Customer AS cu ON cu.CustomerId = i.CustomerId
    GROUP BY cu.CustomerId, cu.Country
) AS s
JOIN Customer AS c ON c.CustomerId = s.CustomerId
JOIN Employee AS e ON e.EmployeeId = c.SupportRepId
JOIN (
    SELECT t.Country, AVG(t.total_spend) AS avg_spend
    FROM (
        SELECT cu2.CustomerId, cu2.Country, SUM(i2.Total) AS total_spend
        FROM Invoice AS i2
        JOIN Customer AS cu2 ON cu2.CustomerId = i2.CustomerId
        GROUP BY cu2.CustomerId, cu2.Country
    ) AS t
    GROUP BY t.Country
) AS a ON a.Country = s.Country
WHERE s.total_spend > a.avg_spend
ORDER BY s.Country, s.total_spend DESC;

-- My refactor 1
WITH total_spend_cte AS(
    SELECT 
        cu.CustomerId, 
        cu.Country, 
        SUM(i.Total) AS total_spend
    FROM 
        Invoice AS i
    JOIN Customer AS cu ON cu.CustomerId = i.CustomerId
    GROUP BY 
        cu.CustomerId, 
        cu.Country
),
avg_spend_cte AS(
    SELECT 
        t.Country, 
        AVG(t.total_spend) AS avg_spend
    FROM 
        total_spend_cte t
    GROUP BY 
        t.Country
)
SELECT
    c.FirstName || ' ' || c.LastName AS customer_name,
    s.Country,
    s.total_spend,
    e.FirstName || ' ' || e.LastName AS rep_name
FROM total_spend_cte AS s
JOIN Customer AS c ON c.CustomerId = s.CustomerId
JOIN Employee AS e ON e.EmployeeId = c.SupportRepId
JOIN avg_spend_cte AS a ON a.Country = s.Country
WHERE s.total_spend > a.avg_spend
ORDER BY s.Country, s.total_spend DESC;

-- Comparing queries
WITH total_spend_cte AS(
    SELECT 
        cu.CustomerId, 
        cu.Country, 
        SUM(i.Total) AS total_spend
    FROM 
        Invoice AS i
    JOIN Customer AS cu ON cu.CustomerId = i.CustomerId
    GROUP BY 
        cu.CustomerId, 
        cu.Country
),
avg_spend_cte AS(
    SELECT 
        t.Country, 
        AVG(t.total_spend) AS avg_spend
    FROM 
        total_spend_cte t
    GROUP BY 
        t.Country
)
SELECT
    c.FirstName || ' ' || c.LastName AS customer_name,
    s.Country,
    s.total_spend,
    e.FirstName || ' ' || e.LastName AS rep_name
FROM total_spend_cte AS s
JOIN Customer AS c ON c.CustomerId = s.CustomerId
JOIN Employee AS e ON e.EmployeeId = c.SupportRepId
JOIN avg_spend_cte AS a ON a.Country = s.Country
WHERE s.total_spend > a.avg_spend
EXCEPT
SELECT
    c.FirstName || ' ' || c.LastName AS customer_name,
    s.Country,
    s.total_spend,
    e.FirstName || ' ' || e.LastName AS rep_name
FROM (
    SELECT cu.CustomerId, cu.Country, SUM(i.Total) AS total_spend
    FROM Invoice AS i
    JOIN Customer AS cu ON cu.CustomerId = i.CustomerId
    GROUP BY cu.CustomerId, cu.Country
) AS s
JOIN Customer AS c ON c.CustomerId = s.CustomerId
JOIN Employee AS e ON e.EmployeeId = c.SupportRepId
JOIN (
    SELECT t.Country, AVG(t.total_spend) AS avg_spend
    FROM (
        SELECT cu2.CustomerId, cu2.Country, SUM(i2.Total) AS total_spend
        FROM Invoice AS i2
        JOIN Customer AS cu2 ON cu2.CustomerId = i2.CustomerId
        GROUP BY cu2.CustomerId, cu2.Country
    ) AS t
    GROUP BY t.Country
) AS a ON a.Country = s.Country
WHERE s.total_spend > a.avg_spend

-- My refactor 2
EXPLAIN QUERY PLAN
WITH customer_spend AS(
    SELECT 
        cu.CustomerId, 
        cu.Country, 
        SUM(i.Total) AS total_spend,
        cu.FirstName || ' ' || cu.LastName AS customer_name,
        cu.SupportRepId,
        AVG(SUM(i.Total)) OVER(PARTITION BY cu.Country) AS avg_spend -- windows run after group by
    FROM 
        Invoice AS i
    JOIN Customer AS cu ON cu.CustomerId = i.CustomerId
    GROUP BY 
        cu.CustomerId, 
        cu.Country,
        cu.FirstName,
        cu.LastName,
        cu.SupportRepId
)
SELECT
    s.customer_name,
    s.Country,
    s.total_spend,
    e.FirstName || ' ' || e.LastName AS rep_name
FROM customer_spend AS s
JOIN Employee AS e ON e.EmployeeId = s.SupportRepId
WHERE s.total_spend > s.avg_spend
ORDER BY s.Country, s.total_spend DESC;

--old
EXPLAIN QUERY PLAN
SELECT
    c.FirstName || ' ' || c.LastName AS customer_name,
    s.Country,
    s.total_spend,
    e.FirstName || ' ' || e.LastName AS rep_name
FROM (
    SELECT cu.CustomerId, cu.Country, SUM(i.Total) AS total_spend
    FROM Invoice AS i
    JOIN Customer AS cu ON cu.CustomerId = i.CustomerId
    GROUP BY cu.CustomerId, cu.Country
) AS s
JOIN Customer AS c ON c.CustomerId = s.CustomerId
JOIN Employee AS e ON e.EmployeeId = c.SupportRepId
JOIN (
    SELECT t.Country, AVG(t.total_spend) AS avg_spend
    FROM (
        SELECT cu2.CustomerId, cu2.Country, SUM(i2.Total) AS total_spend
        FROM Invoice AS i2
        JOIN Customer AS cu2 ON cu2.CustomerId = i2.CustomerId
        GROUP BY cu2.CustomerId, cu2.Country
    ) AS t
    GROUP BY t.Country
) AS a ON a.Country = s.Country
WHERE s.total_spend > a.avg_spend
ORDER BY s.Country, s.total_spend DESC;