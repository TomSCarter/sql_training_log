-- Orientation. List all the tables in the database and the columns of Track and Invoice. Do it with SQL rather than a GUI: SQLite has a system table and a PRAGMA for this.

SELECT name
FROM sqlite_master
WHERE type='table';

PRAGMA table_info(Invoice);

PRAGMA table_info(Artist);

-- Find the 10 most expensive tracks, breaking price ties by longest duration. Show the name, price and duration in seconds, rounded.

SELECT Name, UnitPrice AS Price, CAST(ROUND(Milliseconds/1000.0, 0) AS INTEGER) AS Duration
FROM Track
ORDER BY Price DESC, Milliseconds DESC
LIMIT 10;

-- Find all tracks whose name contains the word "love" in any capitalisation. Then change the query so it excludes names where "love" is only part of a longer word, such as "Lovely". Getting this exactly right is surprisingly fiddly, so a near miss is fine as long as you can explain the edge cases.
SELECT Name
FROM Track
WHERE Name LIKE '%love%'; -- like is case insenitive by default in sqlite

SELECT Name
FROM Track
WHERE ' '||LOWER(Name)||' ' LIKE '% love %'; -- misses those with punctuation, could be addressed with multiple replacements

-- For each billing country, show the number of invoices and the average invoice total, rounded to 2 decimal places. Only include countries with more than 10 invoices, sorted by average total in descending order.
SELECT BillingCountry, ROUND(AVG(Total), 2) AS AVG_Invoice_total, COUNT(InvoiceId) AS num_Invoices
FROM Invoice
GROUP BY BillingCountry
HAVING COUNT(InvoiceId) > 10 --HAVING runs after GROUP BY, WHERE runs before
ORDER BY AVG(Total) DESC

--List each album title with its artist name and the number of tracks on the album.
SELECT al.Title AS album_title, ar.Name AS artist_name, COUNT(t.TrackId) AS number_tracks
FROM Artist AS ar 
INNER JOIN Album AS al USING(ArtistId)
INNER JOIN Track AS t USING(AlbumId)
GROUP BY AlbumId, al.Title, ar.Name;

-- Find any artists who have no albums in the database. Then explain to yourself why moving your NULL check from WHERE into the ON clause gives a different result.
SELECT ar.Name as Artist
FROM Artist AS ar 
LEFT JOIN Album as al USING(ArtistId)
WHERE AlbumId IS NULL;

SELECT ar.Name AS Artist -- returns all Artists because no Albums match (as AlbumId is primary key so impossible to be null and match)
FROM Artist AS ar -- conditions in ON can never remove a left side row in LEFT JOIN
LEFT JOIN Album AS al ON ar.ArtistId = al.ArtistId AND al.AlbumId IS NULL;

--For each genre, find total revenue from invoice lines. Be careful about which table actually holds the price that was charged: there are two candidates, and they can differ.
SELECT g.Name AS genre, SUM(i.UnitPrice * i.Quantity) AS total_revenue
FROM Genre AS g
INNER JOIN Track AS t USING(GenreId)
INNER JOIN InvoiceLine AS i USING(TrackId)
GROUP BY GenreId, g.Name;

-- Add a column to drill 4 that labels each country as "Domestic" if it's the USA and "International" otherwise.

SELECT 
    BillingCountry, 
    ROUND(AVG(Total), 2) AS avg_invoice_total,
    COUNT(InvoiceId) AS num_invoices,
    CASE 
        WHEN BillingCountry = 'USA' THEN 'Domestic' 
        ELSE 'International' 
    END AS market
FROM Invoice
GROUP BY BillingCountry
HAVING COUNT(InvoiceId) > 10
ORDER BY AVG(Total) DESC;