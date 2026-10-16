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
