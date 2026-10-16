# Day 1
- Bucketing
    - Time Taken: ca. 12 min but did give an unintentionly incomplete answer to Claude after 11 min
    - Errors: Lost Case categories in final step, forgot to include them in grouping. Redundant logic: WHEN statements run in order, so lower bounds not needed. Style consistency issues (as/AS, aliases that are functions or tables e.g. count, genre, indents)
    - Concept: A CASE in SELECT is just another per-row expression: it must be grouped by or aggregated.
- Conditional aggregation
    - Time Taken: 15 min, unfinished. Because CASE in SELECT runs after GROUP BY each country was one or >10 or <10. Was going to split into CTE but task says 'a single pass over the Invoice table'?
    - Errors: 
    - Concept: Must be inside aggregate to be run per row in grouping. When you aggregate CASE, the brackets end after END. Non-qualifying rows will be NULL, could make zero with ELSE 0
- WHERE vs HAVING
    - Time Taken: 13min - wrong
    - Errors: The duration filter is in the wrong clause. "Tracks longer than 2 minutes" is a condition on individual tracks, so it's a row filter that must run before grouping. "Overall average" is computed as an average of averages
    - Concept: This is the third time the bare-column leniency has hidden a bug, so it's definitely a Friday pattern. "row filter in HAVING → bare column", "average of averages ≠ overall average (weighting)" "written clause order vs logical execution order" (put WHICH in the right place!)
- Labelling on aggregates
    - Time Taken: 15min - ran out of time, wrote first part but only had 3 min for support rep section and wasted time looking at a join with Employee. Additional 4min to finish correctly.
    - Errors: Used LEFT JOIN then didnt address nulls (should just use INNER). Some indentation missing
    - Concept: NULL comparisons evaluate to unknown, so they fall through to ELSE
- Custom sort order
    - Time Taken: 5 min, small error
    - Errors: 'CANADA' doesnt match 'Canada' should have spotted in output. Style: No brackets needed on CASE
    - Concept: "string equality is case-sensitive; check stored values"
- NULL-aware CASE (Northwind)
    - Time taken: 15 min
    - Errors: Claude poorly framed the problem and wanted ShipperId from a different table (joined by matching two differently named keys), rather than the person who shipped the order as I wrote. I gather Shipper means Courier here not person who shipped. Set CASE to catch NULLS in ELSE, but this mixes them with ERRORS and null requireddate
    - concept 

**look at every expression in SELECT and HAVING and ask, "Is this one value per row or one value per group?" Every per-row expression must be either in GROUP BY or wrapped in an aggregate**

# Day 2

- Redo of Conditional aggregation - 5min
    - Grain = 1 row per country
- 'grain' means what one row represents. e.g. 1 row per invoice, 1 row per track purchased on a invoice. 1 row per customer
- Sprints
    - Four-table chain with name collisions. For each customer, show their full name, their support rep's full name, and the number of distinct genres they've bought. Customer and Employee share column names, so your output needs unambiguous column labels.
        - output grain = 1 row per customer
        - 8.5 min, easy. Correct

            ```
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

        - Tips
            - Would need LEFT JOIN on customer (and all subsequent) to ensure they are all included. distinct_genres would show 0 for customers with no purchase, as COUNT never returns NULL
            - Everything not aggregated needs to be in the GROUP BY to work outside SQLite
            - Qualify the group by (c.CustomerId)

- Self-join with an outer twist. List every employee with their manager's full name. The top of the hierarchy must still appear, showing "No manager" rather than NULL.
    - Grain = 1 row per employee
    - 6 min. Correct

        ```
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
    
    - If ReportsTo pointed to an employeeID that didnt exist (if theyd left), then the ELSE part would come out as null
    - Either test the null on the joined side (e2.FirstName) or (better) use COAELESCE()

- Preserving unmatched rows. List every genre with its total revenue, including genres that have never sold, showing 0 rather than NULL. Then restrict the revenue to a single year of your choice without losing the unsold genres. This is warm-up drill 6 again under time pressure: where the year condition goes decides whether it works.
    - Grain is 1 row per genre
    - 15 min - Couldnt work out how to keep null genres, maybe it needs to be done in two stages (cte). WHERE acts on rows before Grouping, whereas HAVING is on groups where date doesnt make sense? Also couldn't remember how to extract the year from date
        ```
        SELECT 
            g.Name AS genre_name,
            COALESCE(ROUND(SUM(il.Quantity * il.UnitPrice), 2), 0) AS total_revenue
        FROM
            Genre AS g
        LEFT JOIN Track AS t USING(GenreId)
        LEFT JOIN InvoiceLine AS il USING(TrackId)
        LEFT JOIN Invoice AS i USING(InvoiceId)
        WHERE i.InvoiceDate < '2024-01-01' AND i.InvoiceDate >= '2023-01-01'
        GROUP BY 
            g.GenreId, 
            g.Name;
    - Because InvoiceDate is null for the Genres that never sell, they get filtered out. Can put a condition in the join, but doesnt work for a reason I dont fully understand. Need to use a CTE, a nested join or conditional aggregation
    - 
        ```
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
    - First made a CTE where grain is each row is a track with its revenue from 2023
        - Then joined it to a full list of the genres, grouping by genre and aggregating revenue. Joining Genre to the CTE didnt work as that loses all empty genres
    - Come back to cold, still dont totally understand how I should have anticipated this

- The fan-out trap. In one query, show each customer's total invoiced amount (using Invoice.Total) alongside the number of tracks they've bought. Before you trust the result, check one customer's total against a simple single-table query. If the numbers disagree, explain why in your log before fixing it. This is the most important problem today: it's the classic silent bug in real reporting SQL.
    - 14.5 min - Couldnt think of a way to fix the fan out. Removing the join with InvoiceLine fixed it but dont understand exactly why it is happening. I guess joining with InvoiceLine duplicates copies of the Invoice fields on each row, meaning they get counted multiple times. But then how do you ever join it to get track quantity. A window function would avoid collapsing rows but I dont think that helps. Grain is one row per customer

    ```
    SELECT 
        CustomerId,
        FirstName || ' ' || LastName AS customer_name,
        SUM(Total) AS total_invoiced_amount,
        SUM(Quantity) AS number_tracks_bought
    FROM Customer AS c
    LEFT JOIN Invoice AS i USING(CustomerId)
    LEFT JOIN InvoiceLine AS il USING(InvoiceId)
    GROUP BY c.CustomerId, c.FirstName, c.LastName; -- Gives wrong total_invoiced_amount (ca. 10x too big)

    SELECT 
        CustomerId,
        SUM(Total) AS total_invoiced_amount
    FROM
        Invoice
    WHERE CustomerId = 1; -- Shows correct total_invoiced_amount (ca. 38)

    SELECT 
        CustomerId,
        FirstName || ' ' || LastName AS customer_name,
        SUM(Total) AS total_invoiced_amount
    FROM Customer AS c
    LEFT JOIN Invoice AS i USING(CustomerId)
    GROUP BY c.CustomerId, c.FirstName, c.LastName; -- Shows correct total_invoiced_amounts (ca. 38) but no track count
    ```

    - Joining finer grain table to coarser grain, multiples the coarser column, so you cant them sum the coarser column. You have to aggregate before the join to match the grains. So could have prepared two CTEs then done both aggregations after joining them. But I prefered to do 1 CTE inc an aggregation then join and do the other.

    ```
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
     ```


- Northwind join chain. For each shipper (the courier company: Orders.ShipVia joins to Shippers.ShipperID) and each product category, find total revenue, with discount applied, from the order details. The order details table name contains a space, so remember how to quote it.
    - Grain: 1 row is a Shipper with fields for each product category total revenue. Correction: 1 row is a shipper and a product category
    - 15 min. Think i've got the tables the wrong way around
        ```
        WITH cat_rev AS (SELECT od.OrderID, CategoryID, SUM(od.UnitPrice * od.Quantity * od.Discount) AS revenue
        FROM 'Order Details' AS od
        INNER JOIN Products USING(ProductID)
        GROUP BY CategoryID)

        SELECT ShipVia, CategoryID, COALESCE(revenue, 0) AS total_revenue
        FROM Orders
        LEFT JOIN cat_rev USING(OrderId)
        GROUP BY ShipVia, CategoryID;

    - Further 2 min, realised i'd missed some fields from the groupings:
        ```
        WITH cat_rev AS (SELECT od.OrderID, CategoryID, SUM(od.UnitPrice * od.Quantity * od.Discount) AS revenue
        FROM 'Order Details' AS od
        INNER JOIN Products USING(ProductID)
        GROUP BY CategoryID, od.OrderID)

        SELECT ShipVia, CategoryID, ROUND(COALESCE(revenue, 0), 2) AS total_revenue
        FROM cat_rev
        LEFT JOIN Orders USING(OrderId)
        GROUP BY ShipVia, CategoryID
        ORDER BY ShipVia, CategoryID;
    - Final select doesnt aggregate revenue, discount calculation is wrong, CTE isnt needed, use double quotes or []. bare column in a grouped query again. **Make it a rule: every SELECT column is either in the GROUP BY or inside an aggregate.**

- WHERE VS HAVING pair
    - Correct using WHERE
        ```
        EXPLAIN QUERY PLAN
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
        FROM grouped_genres
        WHERE avg_price > (
            SELECT AVG(UnitPrice) 
            FROM Track 
            WHERE Milliseconds > (2 * 60 * 1000)
        );
        ```
    
        ```
                    QUERY PLAN
            |--CO-ROUTINE grouped_genres
            |  |--SCAN t USING INDEX IFK_TrackGenreId
            |  |--SEARCH g USING INTEGER PRIMARY KEY (rowid=?) LEFT-JOIN
            |  |--USE TEMP B-TREE FOR GROUP BY
            |  `--SCALAR SUBQUERY 2
            |     `--SCAN Track
            |--SCAN grouped_genres
            `--SCALAR SUBQUERY 2
            `--SCAN Track
            ```


    - Version using HAVING

        ```
        EXPLAIN QUERY PLAN
        SELECT 
            g.Name AS genre, 
            AVG(t.UnitPrice) AS avg_price
        FROM 
            Track AS t
        LEFT JOIN Genre AS g USING(GenreId)
        WHERE 
            t.Milliseconds > (2 * 60 * 1000)
        GROUP BY 
            GenreId, 
            g.Name
        HAVING 
            AVG(t.UnitPrice) > 
                (SELECT 
                    AVG(UnitPrice) 
                FROM 
                    Track 
                WHERE 
                    Milliseconds > (2 * 60 * 1000)
                );
```

        ```
        QUERY PLAN
        |--SCAN t USING INDEX IFK_TrackGenreId
        |--SEARCH g USING INTEGER PRIMARY KEY (rowid=?) LEFT-JOIN
        |--USE TEMP B-TREE FOR GROUP BY
        `--SCALAR SUBQUERY 1
        `--SCAN Track
     ```

- > **Day 2 theme:** SQLite's leniency hid my bugs. Every column in SELECT or HAVING must be grouped or aggregated, otherwise SQLite silently uses an arbitrary row. A WHERE on the optional table, a later INNER JOIN, or starting from the wrong table all silently undo a LEFT JOIN. Sanity checks against simple single-table queries caught what the output hid.

- Indexing for performance

# Day 3
- Window functions run in SELECT, so cant use the result in WHERE, GROUP BY or HAVING. Need a CTE or subquery
- Default frame is RANGE BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW, rows with equal ORDER BY values (peers) are treated as one unit so get the same running total (inc each others values)
- The fan-out trap. In one query, show each customer's total invoiced amount (using Invoice.Total) alongside the number of tracks they've bought.
    - When combining tables at different grains, joining finer to coarser grain will duplicate the fine values. So if aggregating the fine table values, do it before joining. Think about the grain of the starting tables and intended output at the start.
- BLOCK 1: TIES
- Local: within each genre, rank tracks by unit price using ROW_NUMBER, RANK and DENSE_RANK in one query. Find a genre where all three differ and explain the tie behaviour in your log.
    - No results where all three ranks differ, because there are only 2 prices of track (0.99 and 1.99) and how the prices are spead in Chinook. When using ROW_NUMBER its important to add a second column to ORDER BY as a reproducible tie breaker
- BLOCK 2: TOP-N PER PARTITION
- Local: the top 3 best-selling tracks by quantity in each genre. Aggregate before ranking, and log which ranking function you chose and what happens to a tied fourth track.
    - Spent a few min trying rank vs dense rank vs row number. As there are so many ties, none are meaningful. Chose ROW_NUMBER as top 3 only is specified, and it doesn't show the 10s of ties. Could ORDER BY number_sales then track_name as reproducible tie-break.
- LeetCode 185, Department Top Three Salaries.
- LeetCode 1070
    - Wasted time writing a '1 row per product' query with GROUP BY, read grain more carefully and write it down before writing any SQL
    - RANK or DENSE_RANK would have worked, the former skips to 3 if there is a tie for 1.
- Block 4: Explicit frames
- Local: a 3-invoice moving average of invoice totals for each customer, in date order. Then note when ROWS and RANGE would give different results.
    - ROWS vs RANGE. ROWS defines the number of rows in the window whereas range the values. Range is a way to range between values or a value and current row value, includes duplicates. They differ when there are ties and gaps.
- LeetCode 1321
    - This was a garbage spec that required several reworks to nail down what it actually wanted. Next time look carefully at output and ignore spec text if clearly wrong.
- Block 5: The default-frame trap
- Local only: rank genres by total revenue from highest to lowest, and show each genre's share and the cumulative share (a Pareto view). Then ask whether the running total would still be correct if two genres had identical revenue. This one stays local because the platforms rarely test this trap directly.
    - Issues: fan-out due to SUM(Total) after joining InvoiceLine. SUM(total_revenue) collapses everything, needs to be a window function. cumulative_share was actually cumulative_revenue as written. Round at the end.
    - If RANK or DENSE_RANK is used then tied genres both get the same cumulative share. ROW_NUMBER fixes this, adding g.NAME to ORDER BY stops the tie-break being arbitrary (and possibly not reproducible). A more general fix is to define the window (ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) rather than use the default (unbounded range based on value)


# Day 4
Day 4: LAG/LEAD and Chronological Offsets
- Month-over-month (Block 1)
    - Extracting months in SQLite: strftime('%Y-%m',InvoiceDate) AS shop_month
    - Use NULLIF(..,0) to protect against dividing by 0.
    - COALESCE not need for first month as null less misleading
    - Percentage change divides by the previous month, not the current one
- LeetCode 197 / 180 / Block 4
    - LAG gives the previous row (or a defined number of rows back), not the day before if there are gaps. Have to work around this by also calculating a date differential as a filter
- Average gap (Block 2)
    - A window can't go inside an aggregate as GROUP BY runs first, so it has to be pulled out into a CTE
    - AVG ignores nulls which is good, whereas if converted to zero they'll mess with the denominator in averaging
- LeetCode 550
    - Scalar subqueries must return a single value
    - Postgres quirks
        - Dividing two integers gives an integer not a decimal, one must be converted to numeric
        - General: CAST(value AS numeric)
        - Postgres specific: value::numeric
- Date spine
    - Recursive CTE to generate a calendar of months

        ```
        WITH RECURSIVE calendar AS(
        SELECT date(MIN(InvoiceDate),  'start of month') AS month_start
        FROM Invoice
        UNION ALL
        SELECT date(month_start, '+1 month')
        FROM calendar
        WHERE date(month_start, '+1 month') <= (SELECT MAX(InvoiceDate) FROM Invoice)
        ),
        ```
    
    - Anchor, recursive part, stop condition
    - 'start of month' as second argument in date means the date is always start of the month
    - spine → cross-join with distinct entities → LEFT JOIN facts → COALESCE to 0


# Day 5
Multi-Tier CTEs and Exam Preparation
- CTEs make queries clearer, not faster. Materialisation behaviour depends on the engine
- Refactoring a nested query. Use Except to compare queries, have to remove ORDER BY from both and put CTEs at the very start.
    - Run except in both directions and count rows
    - A window over an aggregate works (GROUP BY before SELECT) and removed a whole join
    - EXPLAIN QUERY PLAN on both versions
        - Old reading Invoice twice and Customer 3 times, fixed in refactor
            - Duplicated logic means duplicated work for the engine

# Pre-flight checklist

- Before writing:
    - Grain of target output? Grain of joining tables (fan out risk)?
    - Check values in example output are consistent with interpretation of spec
    - Is each filter in the right layer?
        - Row conditions in WHERE, group conditions in HAVING, conditions on window in outer query
    - Every scalar subquery must return 1 row
    - Does previous mean previous row or previous date?
- Before runnning:
    - Join types: Left or inner, do we want to keep nulls? does a later WHERE or INNER JOIN undo my LEFT JOIN?
    - Windows: should it be ROWS or RANGE frame? dense/rank/row_number, how are ties dealt with? Does the ORDER BY leave ties? write ROWS explicitly for runnng totals
    - Postgres: Have I given explicit table references and am I dividing integers?
    - Grouping: Is every SELECT column either in the GROUP BY or inside an aggregate?
- After running:
    - Correct column names and number?
    - Row count consistent with intended grain?
    - Check one entities values with a simple single-table query

Trimmed:
- Before writing:
    1. Grain: of the output (confirmed against the example) and of each table I'm joining?
    2. "Previous": previous row or previous date?
- Before running:
    3. Filters: is each one in the right layer (WHERE / HAVING / outer query)?
    4. One value where one is expected: every SELECT column grouped or aggregated? Every scalar subquery returns 1 row?
    5. LEFT JOINs: does a later WHERE or INNER JOIN undo one?
    6. Windows: ties handled, ORDER BY deterministic, ROWS written explicitly?
    7. Integer division? (Postgres: also qualify columns)
- After running:
    8. Row count matches the grain? Spot-check one entity against a simple query.

- Leetcode 1164
    - Grain: 1 row per product from 1 row per price change per product
    - 15 min. But breaks when a product with no price change is input (needing default price of 10). Need to fill those products without a change date with 10?

    ```
        WITH filtered_date AS(
            SELECT 
                product_id,
                new_price,
                change_date
            FROM
                Products
            WHERE change_date <= '2019-08-16'
        ),
        change_dates AS (SELECT
            product_id,
            MAX(change_date) AS recent_change
        FROM
            filtered_date
        GROUP BY
            product_id
        )
        SELECT
            c.product_id,
            p.new_price
        FROM
            change_dates c
        INNER JOIN Products p on c.recent_change = p.change_date AND c.product_id = p.product_id
    ```

    - Faffed around before realising I just needed a list of distinct product_ids

  ```
        WITH filtered_date AS(
            SELECT 
                product_id,
                new_price,
                change_date
            FROM
                Products
            WHERE change_date <= '2019-08-16'
        ),
        latest_date AS (
            SELECT
                product_id,
                MAX(change_date) AS recent_change
            FROM
                filtered_date
            GROUP BY
                product_id
        ),
        latest_price AS (SELECT
                c.product_id,
                p.new_price,
                c.recent_change
            FROM
                latest_date c
            INNER JOIN Products p on c.recent_change = p.change_date AND c.product_id = p.product_id
        )
        SELECT
            p.product_id,
            COALESCE(l.new_price, 10) AS price
        FROM
            (SELECT DISTINCT product_id FROM Products) p
        LEFT JOIN latest_price l ON p.product_id = l.product_id
        ```

- rewrote with window, cleaner

```
        WITH latest_prices AS(
            SELECT
                product_id,
                new_price,
                ROW_NUMBER() OVER(PARTITION BY product_id ORDER BY change_date DESC) AS rank
            FROM
                Products
            WHERE
                change_date <= '2019-08-16'
        )
        SELECT
            x.product_id,
            COALESCE(l.new_price, 10) AS price
        FROM
            (SELECT DISTINCT product_id FROM Products) x 
        LEFT JOIN latest_prices l ON x.product_id = l.product_id
        WHERE rank = 1 OR rank IS NULL
```

- Moved condition from WHERE to ON, more efficient

```
        WITH latest_prices AS(
            SELECT
                product_id,
                new_price,
                ROW_NUMBER() OVER(PARTITION BY product_id ORDER BY change_date DESC) AS rank
            FROM
                Products
            WHERE
                change_date <= '2019-08-16'
        )
        SELECT
            x.product_id,
            COALESCE(l.new_price, 10) AS price
        FROM
            (SELECT DISTINCT product_id FROM Products) x 
        LEFT JOIN latest_prices l ON x.product_id = l.product_id AND rank = 1
```

- Block 2: A multi-tier pipeline from scratch (local, 30 min)

    For each billing country, find the month with its largest month-over-month revenue increase, showing the month, that month's revenue and the size of the increase. Build it on your Day 4 date spine so gaps are handled correctly. Before writing any SQL, write down your CTE chain with one comment line per CTE saying what it holds and its grain. Then fill in the SQL.

    Think about ties: two months with the same increase. That's Day 3's ranking decision again.

    - CTE 1: RECURSIVE CTE holding calendar from InvoiceDate Min to Max, 1 row per month. CROSS JOINED with distinct countries
    - CTE 2: sum(total) GROUP BY country and month to get monthly revenues. Grain reduced from 1 row per invoice to 1 row per country and month
    - CTE 3: LEFT JOIN CTE 2 to CTE 1 and coalesce nulls with 0. Grain 1 row per country and month
    - CTE 4: From CTE3: LAG(monthly_revenue) window PARITION BY country ORDER BY month to give month-over-month increases and amount of increase. 1 row per country and month
    - Final: ROW_NUMBER by revenue increase (partitioning) with month as tie breaker then in outer query Filter to largest revenue increase and return specified rows at grain: 1 row per billing country


# Day 6

- Repeated Leetcode 197: Rising Temp as a warm up (9 min, brain froze for a few minutes, should talk through what i need to calculate)

- Exam
        ```
        Start your timer when you begin reading.

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

        When you're done, paste in your query, your time, and any notes on where the time went.

- Had this after 12min, a couple more min to sort out rounding and names but had no idea how to get a 1/0 flag column.

```
WITH monthly_totals AS (SELECT 
    CustomerId,
    strftime('%Y-%m', InvoiceDate) AS year_month,
    SUM(Total) AS month_spend
FROM
    Invoice
GROUP BY
    CustomerId,
    strftime('%Y-%m', InvoiceDate)
)
SELECT 
    CustomerId,
    FirstName || ' ' || LastName AS customer_name,
    year_month,
    month_spend,
    AVG(month_spend) OVER(PARTITION BY CustomerId ORDER BY year_month) AS running_mean,
    month_spend - AVG(month_spend) OVER(PARTITION BY CustomerId ORDER BY year_month) AS delta_vs_mean
FROM monthly_totals
INNER JOIN Customer USING(CustomerId)
```

- Thought for another 15 min and got to this (which doesnt work). I think SELECT 1 is the right approach but the subquery needs to be joined rather than in select

```
WITH monthly_totals AS (SELECT 
    CustomerId,
    strftime('%Y-%m', InvoiceDate) AS year_month,
    SUM(Total) AS month_spend
FROM
    Invoice
GROUP BY
    CustomerId,
    strftime('%Y-%m', InvoiceDate)
),
 cte AS (SELECT 
    CustomerId AS customer_id,
    FirstName || ' ' || LastName AS customer_name,
    year_month,
    ROUND(month_spend, 2) AS month_spend,
    ROUND(AVG(month_spend) OVER(PARTITION BY CustomerId ORDER BY year_month), 2) AS running_mean,
    ROUND(month_spend - AVG(month_spend) OVER(PARTITION BY CustomerId ORDER BY year_month), 2) AS delta_vs_mean,
    RANK() OVER(PARTITION BY CustomerId ORDER BY month_spend) AS is_peak
FROM monthly_totals
INNER JOIN Customer USING(CustomerId)
ORDER BY CustomerId, year_month
)

SELECT 
    customer_id,
    customer_name,
    year_month,
    month_spend,
    running_mean,
    delta_vs_mean,
    COALESCE((SELECT 1 FROM cte WHERE is_peak = 1), 0) AS is_peak
FROM cte;
```

- CASE statements! Knew I wanted an IF statement but totally forgot that CASE exists after so many window functions...

- SQL toolbox (to help me remember what commands exist)
    - Filter rows
        - WHERE col = value
        - WHERE col IN (subquery or list of values)
            - WHERE col NOT IN (subquery): returns no rows if any nulls, prefer NOT EXISTS
        - WHERE col LIKE '%A_'
        - WHERE EXISTS (subquery)
        - WHERE NOT EXISTS (subquery)
        - WHERE col BETWEEN value AND value
        - WHERE col IS NULL / IS NOT NULL
    - Filter groups
        - HAVING SUM(col) > 5: filter groups by a condition on an aggregate
    - Combine tables
        - INNER JOIN: present in both tables
        - LEFT JOIN: all left values and their matches in right
        - CROSS JOIN: cartesian product
        - UNION: combines 2 queries, no duplicates
        - UNION ALL: combines 2 queries, keeps all records inc duplicates
        - EXCEPT: combines 2 queries, rows from first not in second, no duplicates
        - INTERSECT: combines 2 queries, rows in both, no duplicates
        - ON a.col = b.col AND col = value: resticts which rows match
        - self join: different aliases, useful in a hierarchy or comparing rows in a table
        - anti join (LEFT JOIN + WHERE right.key IS NULL): Finds rows with no match
    - Aggregate
        - COUNT(col) / COUNT(DISTINCT col)
        - SUM
        - AVG: mean
        - MIN / MAX
        - STDDEV (postgres)
        - SUM(CASE WHEN ... THEN ... END): Conditional aggregation
    - Window aggregates
        - All of above with OVER()
        - Frame syntax
            - ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
            - ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
            - RANGE BETWEEN INTERVAL '2' DAY PRECEDING AND CURRENT ROW
    - Query structure
        - CTEs: WITH name AS(query)
        - Subqueries: (query)
        - Windows must go in a CTE to then be filtered in outer query
    - Compute per-row value
        - CASE WHEN col < 2 THEN 1 ELSE 0 END AS name: SQLs IF statement
        - || or CONCAT(col, col): concatenate
        - strftime('%Y-%m', col) AS month
        - julianday(col): decimal days for subtracting
        - UPPER / LOWER(col)
        - ROUND(col, 2)
    - Compare across rows
        - LAG(col, offset, null_fill) OVER(PARTITION BY col2 ORDER BY col3)
        - LEAD(col, offset, null_fill) OVER(PARTITION BY col2 ORDER BY col3)
    - Rank
        - RANK(): ties get same rank number and consecutive ranks are skipped
        - DENSE_RANK(): ties get same rank number and consecutive ranks follow on directly
        - ROW_NUMBER(): all uniquely numbered by row, ties arbitrarily decided unless ORDER BY is determinative
    - Generate rows
        - RECURSIVE CTE: used to generate calendar
    - Handle NULLS and types
        - COALESCE(col, 0)
        - NULLIF(col, 0)
        - CAST(col AS numeric) or col::numeric (postgres)
    - Sort and shape
        - ORDER BY col
        - LIMIT 5
        - SELECT DISTINCT
    - Inspect (SQLite)
        - EXPLAIN QUERY PLAN
        - PRAGMA table_info(table_name)
        - PRAGMA index_list(table_name)
        - PRAGMA index_info(index_name)
        - PRAGMA foreign_key_list(table_name)
        - SELECT name FROM sqlite_master WHERE type = 'table'
        - (Postgres): information_schema.columns
     
# Day 7

- Looked over checklist and toolbox
- Completed Leetcode 184 (highest salary) as warm up (10 min, but lost a couple of min thinking about groupby rather than ranking, and lost a few min just forgetting my ON and putting alias in wrong place)
- Completed Leetcode 1407 (Top Travellers) - 4min
Exam:

## Week 11 Exam (Retake): Genre Monthly Sales Profile

**Database:** Chinook (SQLite)
**Target:** under 12 minutes. **Hard stop:** 25 minutes.
**Allowed:** nothing but the editor and the database.

### Task

For each genre, show units sold month by month, the cumulative total so far, each month's share of the genre's all-time units, and which month was the genre's best.

### Output grain

One row per genre per calendar month **in which at least one track of that genre was sold.** Months with no sales do *not* need to appear.

### Output columns, in this order

| Column | Definition |
|---|---|
| `genre_id` | The genre's ID. |
| `genre_name` | The genre's name. |
| `year_month` | The calendar month of the invoice, formatted `YYYY-MM`. |
| `units_sold` | The total quantity of that genre's tracks sold in that month. |
| `cumulative_units` | The genre's total `units_sold` over all its months **up to and including this one,** in chronological order. |
| `share_of_genre` | This month's `units_sold` divided by the genre's total units across **all** its months, as a decimal between 0 and 1. |
| `is_best_month` | `1` for the genre's single highest-`units_sold` month, `0` for every other month. If two or more months tie for highest, the **most recent** of those months is the best month. Each genre has exactly one best month. |

### Formatting

- Round `share_of_genre` to 3 decimal places, in the final output only.
- Sort by `genre_id`, then `year_month`.

My answer (28 min):
```
WITH monthly_sales AS(
    SELECT
       InvoiceId,
        g.Name AS genre_name,
        SUM(Quantity) AS units_sold
    FROM
        InvoiceLine
    INNER JOIN Track t USING(TrackId)
    INNER JOIN Genre g USING(GenreId)
    GROUP BY g.Name, GenreId, InvoiceId

),

with_months AS (
    SELECT
        strftime('%Y-%m', InvoiceDate) AS sale_month,
        genre_name,
        units_sold
    FROM
        monthly_sales
    INNER JOIN Invoice USING(InvoiceId)
    GROUP BY sale_month, genre_name
    ORDER BY genre_name, sale_month),

windows AS (SELECT
    sale_month,
    genre_name,
    units_sold,
    SUM(units_sold) OVER(PARTITION BY genre_name ORDER BY sale_month) AS cumulative_units,
    CAST(units_sold AS numeric) /  CAST(SUM(units_sold) OVER(PARTITION BY genre_name) AS numeric) AS share_of_genre
FROM
    with_months)

SELECT
    sale_month,
    genre_name,
    units_sold,
    cumulative_units,
    share_of_genre,
    CASE WHEN ROW_NUMBER() OVER(PARTITION BY genre_name ORDER BY units_sold DESC, sale_month DESC) = 1 THEN 1
    ELSE 0 END AS is_best_month
FROM
    windows
```
- Share of genre doesn't work, wasted much time trying to get it to work!
- Analysis
    - Claude told me that CAST(col AS numeric) worked in SQLite, it does not, it gives integers. You have to use CAST(col AS REAL) or just multiply by 1.0. This cost a lot of time
    - I missed units_sold from the initial GROUP BY, so all the values were wrong from there
    - Spelling mismatches, genre_id missing from final output
    - Joining Invoice to InvoiceLine and Track first would have simplified. I was concerned about fan-out or if each invoice contained lines from multiple genres.
        - Because Quantity is on InvoiceLine grain, joining Invoice just adds date

```        
Corrected:
WITH monthly_sales AS(
    SELECT
       InvoiceId,
        g.Name AS genre_name,
        SUM(Quantity) AS units_sold,
        GenreId
    FROM
        InvoiceLine
    INNER JOIN Track t USING(TrackId)
    INNER JOIN Genre g USING(GenreId)
    GROUP BY g.Name, GenreId, InvoiceId

),

with_months AS (
    SELECT
        strftime('%Y-%m', InvoiceDate) AS year_month,
        genre_name,
        SUM(units_sold) AS units_sold,
        GenreId
    FROM
        monthly_sales
    INNER JOIN Invoice USING(InvoiceId)
    GROUP BY year_month, genre_name, GenreId),

windows AS (SELECT
    year_month,
    genre_name,
    units_sold,
    GenreId,
    SUM(units_sold) OVER(PARTITION BY GenreId ORDER BY year_month) AS cumulative_units,
    (units_sold * 1.0) / (1.0 * SUM(units_sold) OVER(PARTITION BY GenreId)) AS share_of_genre
FROM
    with_months)

SELECT
    GenreId AS genre_id,
    genre_name,
    year_month,
    units_sold,
    cumulative_units,
    ROUND(share_of_genre, 3) AS share_of_genre,
    CASE WHEN ROW_NUMBER() OVER(PARTITION BY GenreId ORDER BY units_sold DESC, year_month DESC) = 1 THEN 1
    ELSE 0 END AS is_best_month
FROM
    windows
ORDER BY genre_id, year_month;
