-- Conditional aggregation (pivot). Produce one row per billing country with three columns: total revenue, revenue from invoices of $10 or more, and revenue from invoices under $10. You should only need a single pass over the Invoice table.
SELECT 
    BillingCountry,
    ROUND(SUM(Total), 2) AS total_revenue,
    ROUND(SUM(CASE WHEN Total < 10 THEN Total END), 2) AS small_inv,
    ROUND(SUM(CASE WHEN Total >= 10 THEN Total END), 2) AS large_inv
FROM 
    Invoice
GROUP BY 
    BillingCountry;


-- Four-table chain with name collisions. For each customer, show their full name, their support rep's full name, and the number of distinct genres they've bought. Customer and Employee share column names, so your output needs unambiguous column labels.
SELECT 
    c.FirstName || ' ' || c.LastName AS customer_name,
    e.FirstName || ' ' || e.LastName AS rep_name,
    COUNT(DISTINCT GenreId) AS distinct_genres
FROM 
    Customer AS c
INNER JOIN 
    Employee AS e ON c.SupportRepId = e.EmployeeId
INNER JOIN 
    Invoice USING(CustomerId)
INNER JOIN 
    InvoiceLine USING(InvoiceId)
INNER JOIN 
    Track USING(TrackId)
GROUP BY 
    CustomerId;


-- Self-join with an outer twist. List every employee with their manager's full name. The top of the hierarchy must still appear, showing "No manager" rather than NULL.
SELECT 
    e1.FirstName || ' ' || e1.LastName AS employee_name,
    CASE
        WHEN e1.ReportsTo IS NULL THEN 'No Manager'
        ELSE e2.FirstName || ' ' || e2.LastName
    END AS manager_name
FROM 
    Employee AS e1
LEFT JOIN 
    Employee AS e2 ON e1.ReportsTo = e2.EmployeeId;

-- Preserving unmatched rows. List every genre with its total revenue, including genres that have never sold, showing 0 rather than NULL. Then restrict the revenue to a single year of your choice without losing the unsold genres. This is warm-up drill 6 again under time pressure: where the year condition goes decides whether it works.
SELECT 
    e1.FirstName || ' ' || e1.LastName AS employee_name,
    COALESCE(e2.FirstName || ' ' || e2.LastName, 'No manager') AS manager_name
FROM 
    Employee AS e1
LEFT JOIN 
    Employee AS e2 ON e1.ReportsTo = e2.EmployeeId;

-- The fan-out trap. In one query, show each customer's total invoiced amount (using Invoice.Total) alongside the number of tracks they've bought. Before you trust the result, check one customer's total against a simple single-table query. If the numbers disagree, explain why in your log before fixing it. This is the most important problem today: it's the classic silent bug in real reporting SQL.
WITH cte_2023 AS(
    SELECT
       TrackId,
       (il.Quantity * il.UnitPrice) AS revenue
    FROM
        InvoiceLine AS il
    INNER JOIN Invoice AS i USING(InvoiceId)
    WHERE i.InvoiceDate < '2024-01-01' AND i.InvoiceDate >= '2023-01-01'
)

SELECT 
    g.Name AS genre_name,
     ROUND(SUM(COALESCE(revenue, 0)), 2) AS total_revenue
FROM
    Genre AS g
LEFT JOIN Track AS t USING(GenreId)
LEFT JOIN cte_2023 AS c USING(TrackId)
GROUP BY 
    g.GenreId, 
    g.Name;

WITH num_tracks_per_inv AS(
    SELECT 
        CustomerId,
        SUM(Quantity) AS num_tracks,
        Total
    FROM Invoice AS i
    LEFT JOIN InvoiceLine AS il USING(InvoiceId)
    GROUP BY 
        i.InvoiceId
)
SELECT 
    FirstName || ' ' || LastName AS customer_name,
    SUM(Total) AS total_invoiced_amount,
    SUM(num_tracks) AS number_tracks_bought
FROM Customer AS c
LEFT JOIN num_tracks_per_inv USING(CustomerId)
GROUP BY 
    c.CustomerId, 
    c.FirstName, 
    c.LastName;

--Northwind join chain. For each shipper (the courier company: Orders.ShipVia joins to Shippers.ShipperID) and each product category, find total revenue, with discount applied, from the order details. The order details table name contains a space, so remember how to quote it.
-- Orders (ShipVia), Order Details(per product - UnitPrice, Quantity, Discount), Products(CategoryId)

WITH cat_rev AS (
    SELECT 
        od.OrderID, 
        CategoryID, 
        SUM(od.UnitPrice * od.Quantity * (1 - od.Discount)) AS revenue
FROM 
    "Order Details" AS od
INNER JOIN Products USING(ProductID)
GROUP BY 
    CategoryID, od.OrderID
)

SELECT 
    ShipVia, 
    CategoryID, 
    ROUND(SUM(COALESCE(revenue, 0)), 2) AS total_revenue
FROM 
    cat_rev
LEFT JOIN Orders USING(OrderId)
GROUP BY 
    ShipVia, 
    CategoryID
ORDER BY 
    ShipVia, 
    CategoryID;