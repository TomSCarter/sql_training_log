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

        
        QUERY PLAN
        |--SCAN t USING INDEX IFK_TrackGenreId
        |--SEARCH g USING INTEGER PRIMARY KEY (rowid=?) LEFT-JOIN
        |--USE TEMP B-TREE FOR GROUP BY
        `--SCALAR SUBQUERY 1
        `--SCAN Track
     
- > **Day 2 theme:** SQLite's leniency hid my bugs. Every column in SELECT or HAVING must be grouped or aggregated, otherwise SQLite silently uses an arbitrary row. A WHERE on the optional table, a later INNER JOIN, or starting from the wrong table all silently undo a LEFT JOIN. Sanity checks against simple single-table queries caught what the output hid.

- Indexing for performance

# Day 3
- Window functions run in SELECT, so cant use the result in WHERE, GROUP BY or HAVING. Need a CTE or subquery
- Default frame is RANGE BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW, rows with equal ORDER BY values (peers) are treated as one unit so get the same running total (inc each others values)
