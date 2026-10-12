-- Cold re-do fan-out drill from day 2
-- The fan-out trap. In one query, show each customer's total invoiced amount (using Invoice.Total) alongside the number of tracks they've bought.
-- Grain: 1 row per customer
WITH invoice_totals AS (
    SELECT
        CustomerId,
        SUM(Total) AS inv_total
    FROM
        Invoice
    GROUP BY
        CustomerId
), -- Grain: 1 row per invoice to 1 row per customer
track_count AS (
    SELECT
        CustomerId,
        SUM(Quantity) AS num_tracks
    FROM 
        InvoiceLine
    INNER JOIN Invoice USING(InvoiceId)
    GROUP BY
        CustomerId
) -- Grain: 1 row per track on invoice to 1 row per customer

SELECT 
    FirstName || ' ' || LastName AS customer_name, 
    inv_total,
    num_tracks
FROM 
    Customer
LEFT JOIN invoice_totals USING(CustomerId)
LEFT JOIN track_count USING(CustomerId)
-- 14:43 min
