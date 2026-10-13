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


-- BLOCK 1: TIES
-- Local: within each genre, rank tracks by unit price using ROW_NUMBER, RANK and DENSE_RANK in one query. Find a genre where all three differ and explain the tie behaviour in your log.
-- Grain: 1 row per track with 3 diff ranks (within genre)

SELECT 
    t.Name AS track_name,
    g.Name AS genre_name,
    g.GenreId,
    t.UnitPrice,
    ROW_NUMBER() OVER(PARTITION BY GenreId ORDER BY t.UnitPrice) AS row_number_rank,
    RANK() OVER(PARTITION BY GenreId ORDER BY t.UnitPrice) AS rank_rank,
    DENSE_RANK() OVER(PARTITION BY GenreId ORDER BY t.UnitPrice) AS dense_rank_rank
FROM
    Track AS t
INNER JOIN Genre AS g USING(GenreId)
-- 6min

WITH ranks AS (SELECT 
    t.Name AS track_name,
    g.Name AS genre_name,
    g.GenreId,
    t.UnitPrice,
    ROW_NUMBER() OVER(PARTITION BY GenreId ORDER BY t.UnitPrice) AS row_number_rank,
    RANK() OVER(PARTITION BY GenreId ORDER BY t.UnitPrice) AS rank_rank,
    DENSE_RANK() OVER(PARTITION BY GenreId ORDER BY t.UnitPrice) AS dense_rank_rank
FROM
    Track AS t
INNER JOIN Genre AS g USING(GenreId)
)
SELECT *
FROM ranks
WHERE row_number_rank <> rank_rank AND row_number_rank <> dense_rank_rank AND rank_rank <> dense_rank_rank
-- 11 min total
-- No results where all three ranks differ, because there are only 2 prices of track (0.99 and 1.99)

-- LeetCode 178
SELECT
    score,
    DENSE_RANK() OVER(ORDER BY score DESC) AS rank
FROM Scores
ORDER BY score DESC
-- 4min 20



-- BLOCK 2: TOP-N PER PARTITION
-- Local: the top 3 best-selling tracks by quantity in each genre. Aggregate before ranking, and log which ranking function you chose and what happens to a tied fourth track.
-- Grain: 1 track per row, 3 ranked by quantity, per genre

WITH sales_numbers AS(SELECT
    t.TrackId,
    t.Name AS track_name,
    g.Name AS genre_name,
    g.GenreId,
    SUM(i.Quantity) AS number_sales
FROM InvoiceLine AS i
INNER JOIN Track AS t USING(TrackId)
INNER JOIN Genre AS g USING(GenreId)
GROUP BY i.TrackId, t.Name, g.GenreId, g.Name),

sales_ranks AS(
    SELECT
        track_name,
        genre_name,
        number_sales,
        ROW_NUMBER() OVER(PARTITION BY genre_name ORDER BY number_sales DESC) AS sales_rank
    FROM
        sales_numbers)

SELECT
    track_name,
    genre_name,
    number_sales,
    sales_rank
FROM
    sales_ranks
WHERE sales_rank <= 3;
-- 14 min. Spent a few min trying rank vs dense rank vs row number. As there are so many ties, none are meaningful. Chose ROW_NUMBER as top 3 only is specified, and it doesn't show the 10s of ties. Could ORDER BY number_sales then track_name as reproducible tie-break.


-- Transfer: LeetCode 185, Department Top Three Salaries. The problem's definition of "top three" settles the tie question for you, so read it carefully.
-- Grain: 1 row per employee
-- Write your PostgreSQL query statement below
WITH dep_rank_cte AS(
        SELECT
            d.Name AS Department,
            e.Name AS Employee,
            salary AS Salary,
            DENSE_RANK() OVER(PARTITION BY departmentId ORDER BY salary DESC) AS dep_rank
        FROM
            Employee AS e
        INNER JOIN Department AS d ON e.departmentId = d.id
)
SELECT
    Department,
    Employee,
    Salary
FROM
    dep_rank_cte
WHERE
    dep_rank <= 3
-- 7:15 min

-- Block 3: First/latest record per entity
-- Transfer only: LeetCode 1070, Product Sales Analysis III. It's the same deduplication pattern as the latest-invoice-per-customer drill, but with a twist where more than one row can share the "first" position. Choosing the right ranking function is the whole problem.
-- Write your PostgreSQL query statement below
-- Grain: 1 Row per sale
WITH cte AS(
    SELECT
        product_id,
        DENSE_RANK() OVER(PARTITION BY product_id ORDER BY year) AS year_rank,
        year,
        quantity,
        price
    FROM
        Sales
)
SELECT
    product_id,
    year AS first_year,
    quantity,
    price
FROM
    cte
WHERE year_rank = 1
-- 15min. Wasted time writing a '1 row per product' query with GROUP BY, read grain more carefully rather than just looking at target output.
-- RANK or DENSE_RANK would have worked, the former skips to 3 if there is a tie for 1.



-- Block 4: Explicit frames
-- Local: a 3-invoice moving average of invoice totals for each customer, in date order. Then note when ROWS and RANGE would give different results.
--Grain: 1 row per Invoice
SELECT
    InvoiceId,
    InvoiceDate,
    FirstName || ' ' || LastName AS customer_name,
    ROUND(AVG(Total) OVER(PARTITION BY CustomerId ORDER BY InvoiceDate ROWS BETWEEN 2 PRECEDING AND CURRENT ROW), 2) AS moving_average_inv
FROM
    Invoice
INNER JOIN Customer USING(CustomerId)
-- 6:19 min. But did have to look up the syntax for 'ROWS BETWEEN...'
-- Not familar with RANGE? It is a way to range between values or a value and current row value, includes duplicates
SELECT
    InvoiceId,
    InvoiceDate,
    FirstName || ' ' || LastName AS customer_name,
    Total,
    ROUND(AVG(Total) OVER(PARTITION BY CustomerId ORDER BY InvoiceDate, InvoiceId ROWS BETWEEN 2 PRECEDING AND CURRENT ROW), 2) AS moving_average_inv
FROM
    Invoice
INNER JOIN Customer USING(CustomerId)
-- Added tie-break on ORDER BY and Total to SELECT




-- Transfer: LeetCode 1321, Restaurant Growth. It's a grain test too: think about what one row should represent before you apply any window.
-- Grain: 1 row per transaction/customer_visit
SELECT
    visited_on,
    amount,
    ROUND(AVG(amount) OVER(PARTITION BY customer_id ORDER BY visited_on RANGE BETWEEN INTERVAL '6' DAY PRECEDING AND CURRENT ROW), 2) AS average_amount
FROM
    Customer
ORDER BY
    visited_on
-- 11min. But no idea how to remove the rows that are averaging over less than 7 days?
-- Spent another 20 min working on this but needs rewriting with an initial group by date. The spec is really crap and misleading, 'Compute the moving average of how much the customer paid' should be moving average of total daily sales for the store, shoud mention you need to filter out the first 6 days.
-- Another 20min on this, but finally working. The spec really is bad
WITH
customer_totals AS(
    SELECT
        visited_on,
        SUM(amount) AS amount
    FROM 
        Customer
    GROUP BY
        visited_on
),
windowed AS(
    SELECT
        visited_on,
        SUM(amount) OVER(ORDER BY visited_on RANGE BETWEEN INTERVAL '6' DAY PRECEDING AND CURRENT ROW) AS seven_day_total,
        AVG(amount) OVER(ORDER BY visited_on RANGE BETWEEN INTERVAL '6' DAY PRECEDING AND CURRENT ROW) AS average_amount
    FROM customer_totals
)
SELECT
    visited_on,
    seven_day_total AS amount,
    ROUND(average_amount, 2) AS average_amount
FROM windowed
WHERE visited_on >= (SELECT MIN(visited_on) FROM Customer) + 6
ORDER BY visited_on



-- Block 5: The default-frame trap
-- Local only: rank genres by total revenue from highest to lowest, and show each genre's share and the cumulative share (a Pareto view). Then ask whether the running total would still be correct if two genres had identical revenue. This one stays local because the platforms rarely test this trap directly.
--Grain: 1 genre per row
WITH total_rev_cte AS (
    SELECT
        g.Name AS genre_name,
        g.GenreId,
        ROUND(SUM(i.Total), 2) AS total_revenue,
        RANK() OVER(ORDER BY SUM(i.Total) DESC) AS g_rank
    FROM
        InvoiceLine AS il
    INNER JOIN Track AS t USING(TrackId)
    INNER JOIN Invoice AS i USING(InvoiceId)
    INNER JOIN Genre AS g USING(GenreId)
    GROUP BY
        g.GenreId, 
        g.Name
)

SELECT
    genre_name,
    total_revenue,
    (total_revenue / SUM(total_revenue)) AS share, -- doesnt work
    SUM(total_revenue) OVER(ORDER BY g_rank) AS cumulative_share,
    g_rank
FROM total_rev_cte
-- 15 min. Could not work out how to get the share of total, without output collapsing to 1 row? Tried a subquery but didnt work
-- Issues: fan-out due to SUM(Total) after joining InvoiceLine. SUM(total_revenue) collapses everything, needs to be a window function. cumulative_share is actually cumulative_revenue as written. Round at the end. How does the running total deal with ties?
--Rework:
WITH total_rev_cte AS (
    SELECT
        g.Name AS genre_name,
        g.GenreId,
        SUM(il.UnitPrice * il.Quantity) AS total_revenue,
        ROW_NUMBER() OVER(ORDER BY SUM(il.UnitPrice * il.Quantity) DESC, g.Name DESC) AS g_rank
    FROM
        InvoiceLine AS il
    INNER JOIN Track AS t USING(TrackId)
    INNER JOIN Genre AS g USING(GenreId)
    GROUP BY
        g.GenreId, 
        g.Name
)

SELECT
    genre_name,
    total_revenue,
    ROUND(
        (total_revenue/SUM(total_revenue) OVER()), 
        3) AS share,
    ROUND(
        (SUM(total_revenue) OVER(ORDER BY g_rank) / SUM(total_revenue) OVER())
        , 3) AS cumulative_share,
    g_rank
FROM total_rev_cte
-- If RANK or DENSE_RANK is used then tied genres both get the same cumulative share. ROW_NUMBER fixes this, adding g.NAME to ORDER BY stops the tie-break being arbitrary (and possibly not reproducible). A more general fix is to define the window (ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) rather than use the default (unbounded range based on value)

-- Optional transfer if time allows: LeetCode 1204, Last Person to Fit in the Bus, which uses a running total as a stopping condition.