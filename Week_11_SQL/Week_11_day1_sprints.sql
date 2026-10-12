-- Bucketing. Classify every track as Short (under 3 min), Medium (3–6 min) or Long (over 6 min). For each genre, show how many tracks fall into each bucket. Watch the units the Milliseconds column uses and where your boundaries sit.
WITH cte AS (SELECT
g.Name as genre,
    CASE
        WHEN Milliseconds < (3 * 60 * 1000) THEN 'Short'
        WHEN Milliseconds >= (3 * 60 * 1000) AND Milliseconds <= (6 * 60 * 1000) THEN 'Medium'
        ELSE 'Long'
    END AS length
FROM Track
INNER JOIN Genre g USING(GenreId))
SELECT genre, COUNT(length) as count
FROM cte
GROUP BY Genre;

-- Conditional aggregation (pivot). Produce one row per billing country with three columns: total revenue, revenue from invoices of $10 or more, and revenue from invoices under $10. You should only need a single pass over the Invoice table.
SELECT 
    BillingCountry, 
    SUM(Total) AS total_revenue,
    SUM( 
        CASE
            WHEN Total >= 10 THEN Total
        END) AS inv_10_or_more,
    SUM(
        CASE
            WHEN Total < 10 THEN Total
        END) AS inv_under_10
FROM Invoice
GROUP BY 
    BillingCountry;


-- WHERE vs HAVING. Find genres whose average unit price is above the overall average unit price, counting only tracks longer than 2 minutes. Before you start, decide which condition is a row filter and which is a group filter.
WITH grouped_genres AS (
    SELECT 
        g.Name AS genre, 
        AVG(t.UnitPrice) AS avg_price
    FROM Track AS t
    LEFT JOIN Genre AS g USING(GenreId)
    WHERE t.Milliseconds > (2 * 60 * 1000)
    GROUP BY GenreId, g.Name
)

SELECT 
    genre, 
    avg_price
FROM cte
WHERE avg_price > (
    SELECT AVG(UnitPrice) 
    FROM Track 
    WHERE Milliseconds > (2 * 60 * 1000)
);

-- Labelling on aggregates. Label each customer High, Mid or Low value based on lifetime spend (choose sensible thresholds after a quick look at the distribution). Then, for each support rep, count their High-value customers and show only reps with at least 3. Think about whether this fits in one query level or needs layering.
WITH spend AS (
    SELECT 
        c.FirstName ||' '|| c.LastName AS customer_name, 
        SUM(i.Total) AS lifetime_spend,
        CASE 
            WHEN SUM(i.Total) < 34 THEN 'Low'
            WHEN SUM(i.Total) < 38 THEN 'Mid'
            ELSE 'High'
        END AS lifetime_spend_rating,
        c.SupportRepId,
        c.CustomerId
    FROM Customer AS c
    INNER JOIN Invoice AS i USING(CustomerId)
    GROUP BY CustomerId
)

SELECT 
    SupportRepId, 
    COUNT(CustomerId) AS number_high_value_customers
FROM spend
WHERE lifetime_spend_rating = 'High'
GROUP BY SupportRepId
HAVING COUNT(CustomerId) >= 3;

--Custom sort order. List customers sorted with USA first, then Canada, then all other countries alphabetically, and by last name within each country.
SELECT 
    CustomerId, 
    LastName, 
    Country
FROM Customer
ORDER BY CASE
            WHEN Country = 'USA' THEN 1
            WHEN Country = 'Canada' THEN 2
            ELSE 3
        END, 
        Country, 
        LastName;

-- NULL-aware CASE (Northwind). Classify every order as "Not shipped", "Shipped late" or "Shipped on time" using ShippedDate and RequiredDate. Then count orders per category for each shipper. The order of your WHEN branches matters here, so think about it before you write any code.
WITH shipped_classes AS (
    SELECT
        ShipVia,
        RequiredDate,
        ShippedDate,
        CASE
            WHEN ShippedDate IS NULL THEN 'Not shipped'
            WHEN ShippedDate < RequiredDate THEN 'Shipped on time'
            WHEN ShippedDate >= RequiredDate THEN 'Shipped late'
            ELSE 'ERROR'
        END AS shipping_status
    FROM Orders
)
SELECT 
    ShipVia AS shipper_id, 
    shipping_status, 
    COUNT(shipping_status) AS counted_status
FROM shipped_classes
GROUP BY 
    ShipVia, 
    shipping_status;


