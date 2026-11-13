
### [14:35:03] Exam — +625.7s since last run | SUCCESS (0 rows, 112.0ms)
```sql
-- Exam
-- Base: district, year, £/m2. Filter year, property type etc
-- Agg: group by district x year
-- Windows: LAG median price, calc change, rank year change
-- Final:  CASE best year
-- Final grain: 1 row per district
```

---

### [14:39:56] Exam — +292.5s since last run | SUCCESS (102460 rows, 568.8ms)
```sql
-- Exam
-- Base: district, year, calc £/m2. Filter year, property type etc
-- Agg: group by district x year
-- Windows: LAG median price, calc change, rank year change
-- Final:  CASE best year
-- Final grain: 1 row per district

SELECT 
    district, 
    year, 
    price_paid / total_floor_area AS ppsqm
FROM
    sales
WHERE year BETWEEN 2015 AND 2024 
    AND property_subtype <> 'O' 
    AND total_floor_area IS NOT NULL
    AND total_floor_area BETWEEN 15 AND 500;
```

---

### [14:41:38] Exam — +102.5s since last run | SUCCESS (50 rows, 246.8ms)
```sql
-- Exam
-- Base: district, year, calc £/m2. Filter year, property type etc
-- Agg: group by district x year
-- Windows: LAG median price, calc change, rank year change
-- Final:  CASE best year
-- Final grain: 1 row per district

WITH base AS (
SELECT 
    district, 
    year, 
    price_paid / total_floor_area AS ppsqm
FROM
    sales
WHERE year BETWEEN 2015 AND 2024 
    AND property_subtype <> 'O' 
    AND total_floor_area IS NOT NULL
    AND total_floor_area BETWEEN 15 AND 500)

SELECT 
    district, 
    year, 
    MEDIAN(ppsqm) AS median_ppsqm
FROM
    base
GROUP BY
    district,
    year;
```

---

### [14:42:54] Exam — +75.6s since last run | SUCCESS (50 rows, 169.8ms)
```sql
-- Exam
-- Base: district, year, calc £/m2. Filter year, property type etc
-- Agg: group by district x year
-- Windows: LAG median price, calc change, rank year change
-- Final:  CASE best year
-- Final grain: 1 row per district

WITH base AS (
SELECT 
    district, 
    year, 
    price_paid / total_floor_area AS ppsqm
FROM
    sales
WHERE year BETWEEN 2015 AND 2024 
    AND property_subtype <> 'O' 
    AND total_floor_area IS NOT NULL
    AND total_floor_area BETWEEN 15 AND 500)

SELECT 
    district, 
    year, 
    MEDIAN(ppsqm) AS median_ppsqm,
    COUNT(ppsqm)
FROM
    base
GROUP BY
    district,
    year
;
```

---

### [14:43:39] Exam — +44.9s since last run | SUCCESS (50 rows, 200.8ms)
```sql
-- Exam
-- Base: district, year, calc £/m2. Filter year, property type etc
-- Agg: group by district x year
-- Windows: LAG median price, calc change, rank year change
-- Final:  CASE best year
-- Final grain: 1 row per district

WITH base AS (
SELECT 
    district, 
    year, 
    price_paid / total_floor_area AS ppsqm
FROM
    sales
WHERE year BETWEEN 2015 AND 2024 
    AND property_subtype <> 'O' 
    AND total_floor_area IS NOT NULL
    AND total_floor_area BETWEEN 15 AND 500)

SELECT 
    district, 
    year, 
    MEDIAN(ppsqm) AS median_ppsqm
FROM
    base
GROUP BY
    district,
    year
HAVING COUNT(ppsqm) >= 30;
```

---

### [14:46:18] Exam — +158.9s since last run | SUCCESS (50 rows, 180.1ms)
```sql
-- Exam
-- Base: district, year, calc £/m2. Filter year, property type etc
-- Agg: group by district x year
-- Windows: LAG median price, calc change, rank year change
-- Final:  CASE best year
-- Final grain: 1 row per district

WITH base AS (
SELECT 
    district, 
    year, 
    price_paid / total_floor_area AS ppsqm
FROM
    sales
WHERE year BETWEEN 2015 AND 2024 
    AND property_subtype <> 'O' 
    AND total_floor_area IS NOT NULL
    AND total_floor_area BETWEEN 15 AND 500),

agg AS (SELECT 
    district, 
    year, 
    MEDIAN(ppsqm) AS median_ppsqm
FROM
    base
GROUP BY
    district,
    year
HAVING COUNT(ppsqm) >= 30)

SELECT 
    district, 
    year, 
    median_ppsqm,
    LAG(median_ppsqm) OVER(PARTITION BY district ORDER BY year) AS prev_median_ppsqm,
    median_ppsqm - (LAG(median_ppsqm) OVER(PARTITION BY district ORDER BY year)) AS yoy_pct
FROM
    agg;
```

---

### [14:47:20] Exam — +61.7s since last run | SUCCESS (50 rows, 164.6ms)
```sql
-- Exam
-- Base: district, year, calc £/m2. Filter year, property type etc
-- Agg: group by district x year
-- Windows: LAG median price, calc change, rank year change
-- Final:  CASE best year
-- Final grain: 1 row per district

WITH base AS (
SELECT 
    district, 
    year, 
    price_paid / total_floor_area AS ppsqm
FROM
    sales
WHERE year BETWEEN 2015 AND 2024 
    AND property_subtype <> 'O' 
    AND total_floor_area IS NOT NULL
    AND total_floor_area BETWEEN 15 AND 500),

agg AS (SELECT 
    district, 
    year, 
    MEDIAN(ppsqm) AS median_ppsqm
FROM
    base
GROUP BY
    district,
    year
HAVING COUNT(ppsqm) >= 30)

SELECT 
    district, 
    year, 
    median_ppsqm,
    LAG(median_ppsqm) OVER(PARTITION BY district ORDER BY year) AS prev_median_ppsqm,
    100 * (median_ppsqm - (LAG(median_ppsqm) OVER(PARTITION BY district ORDER BY year))) / LAG(median_ppsqm) OVER(PARTITION BY district ORDER BY year) AS yoy_pct
FROM
    agg;
```

---

### [14:47:45] Exam — +25.6s since last run | SUCCESS (50 rows, 119.1ms)
```sql
-- Exam
-- Base: district, year, calc £/m2. Filter year, property type etc
-- Agg: group by district x year
-- Windows: LAG median price, calc change, rank year change
-- Final:  CASE best year
-- Final grain: 1 row per district

WITH base AS (
SELECT 
    district, 
    year, 
    price_paid / total_floor_area AS ppsqm
FROM
    sales
WHERE year BETWEEN 2015 AND 2024 
    AND property_subtype <> 'O' 
    AND total_floor_area IS NOT NULL
    AND total_floor_area BETWEEN 15 AND 500),

agg AS (SELECT 
    district, 
    year, 
    MEDIAN(ppsqm) AS median_ppsqm
FROM
    base
GROUP BY
    district,
    year
HAVING COUNT(ppsqm) >= 30)

SELECT 
    district, 
    year, 
    median_ppsqm,
    LAG(median_ppsqm) OVER(PARTITION BY district ORDER BY year) AS prev_median_ppsqm,
    ROUND(100 * (median_ppsqm - (LAG(median_ppsqm) OVER(PARTITION BY district ORDER BY year))) / LAG(median_ppsqm) OVER(PARTITION BY district ORDER BY year), 1) AS yoy_pct
FROM
    agg;
```

---

### [14:50:20] Exam — +155.2s since last run | SUCCESS (50 rows, 145.4ms)
```sql
-- Exam
-- Base: district, year, calc £/m2. Filter year, property type etc
-- Agg: group by district x year
-- Windows: LAG median price, calc change, rank year change
-- Final:  CASE best year
-- Final grain: 1 row per district

WITH base AS (
SELECT 
    district, 
    year, 
    price_paid / total_floor_area AS ppsqm
FROM
    sales
WHERE year BETWEEN 2015 AND 2024 
    AND property_subtype <> 'O' 
    AND total_floor_area IS NOT NULL
    AND total_floor_area BETWEEN 15 AND 500),

agg AS (SELECT 
    district, 
    year, 
    MEDIAN(ppsqm) AS median_ppsqm
FROM
    base
GROUP BY
    district,
    year
HAVING COUNT(ppsqm) >= 30),

win AS (SELECT 
    district, 
    year, 
    median_ppsqm,
    LAG(median_ppsqm) OVER(PARTITION BY district ORDER BY year) AS prev_median_ppsqm,
    ROUND(100 * (median_ppsqm - (LAG(median_ppsqm) OVER(PARTITION BY district ORDER BY year))) / LAG(median_ppsqm) OVER(PARTITION BY district ORDER BY year), 1) AS yoy_pct
FROM
    agg)
    
SELECT 
    district, 
    year, 
    median_ppsqm,
    prev_median_ppsqm,
    yoy_pct,
    RANK() OVER(PARTITION BY district ORDER BY yoy_pct DESC, year ASC) AS year_rank
FROM
    win;
```

---

### [14:52:30] Exam — +129.7s since last run | ERROR (77.9ms)

> **Error:** `Parser Error: syntax error at or near "win2" | LINE 39:`
```sql
-- Exam
-- Base: district, year, calc £/m2. Filter year, property type etc
-- Agg: group by district x year
-- Windows: LAG median price, calc change, rank year change
-- Final:  CASE best year
-- Final grain: 1 row per district

WITH base AS (
SELECT 
    district, 
    year, 
    price_paid / total_floor_area AS ppsqm
FROM
    sales
WHERE year BETWEEN 2015 AND 2024 
    AND property_subtype <> 'O' 
    AND total_floor_area IS NOT NULL
    AND total_floor_area BETWEEN 15 AND 500),

agg AS (SELECT 
    district, 
    year, 
    MEDIAN(ppsqm) AS median_ppsqm
FROM
    base
GROUP BY
    district,
    year
HAVING COUNT(ppsqm) >= 30),

win AS (SELECT 
    district, 
    year, 
    median_ppsqm,
    LAG(median_ppsqm) OVER(PARTITION BY district ORDER BY year) AS prev_median_ppsqm,
    ROUND(100 * (median_ppsqm - (LAG(median_ppsqm) OVER(PARTITION BY district ORDER BY year))) / LAG(median_ppsqm) OVER(PARTITION BY district ORDER BY year), 1) AS yoy_pct
FROM
    agg)
    
win2 AS (SELECT 
    district, 
    year, 
    median_ppsqm,
    prev_median_ppsqm,
    yoy_pct,
    RANK() OVER(PARTITION BY district ORDER BY yoy_pct DESC, year ASC) AS year_rank
FROM
    win)

SELECT 
    district, 
    year AS best_year, 
    median_ppsqm,
    prev_median_ppsqm,
    yoy_pct
FROM
    win2
WHERE year_rank = 1
;
```

---

### [14:52:38] Exam — +7.9s since last run | SUCCESS (5 rows, 176.4ms)
```sql
-- Exam
-- Base: district, year, calc £/m2. Filter year, property type etc
-- Agg: group by district x year
-- Windows: LAG median price, calc change, rank year change
-- Final:  CASE best year
-- Final grain: 1 row per district

WITH base AS (
SELECT 
    district, 
    year, 
    price_paid / total_floor_area AS ppsqm
FROM
    sales
WHERE year BETWEEN 2015 AND 2024 
    AND property_subtype <> 'O' 
    AND total_floor_area IS NOT NULL
    AND total_floor_area BETWEEN 15 AND 500),

agg AS (SELECT 
    district, 
    year, 
    MEDIAN(ppsqm) AS median_ppsqm
FROM
    base
GROUP BY
    district,
    year
HAVING COUNT(ppsqm) >= 30),

win AS (SELECT 
    district, 
    year, 
    median_ppsqm,
    LAG(median_ppsqm) OVER(PARTITION BY district ORDER BY year) AS prev_median_ppsqm,
    ROUND(100 * (median_ppsqm - (LAG(median_ppsqm) OVER(PARTITION BY district ORDER BY year))) / LAG(median_ppsqm) OVER(PARTITION BY district ORDER BY year), 1) AS yoy_pct
FROM
    agg),
    
win2 AS (SELECT 
    district, 
    year, 
    median_ppsqm,
    prev_median_ppsqm,
    yoy_pct,
    RANK() OVER(PARTITION BY district ORDER BY yoy_pct DESC, year ASC) AS year_rank
FROM
    win)

SELECT 
    district, 
    year AS best_year, 
    median_ppsqm,
    prev_median_ppsqm,
    yoy_pct
FROM
    win2
WHERE year_rank = 1
;
```

---

### [14:53:36] Exam — +58.2s since last run | SUCCESS (5 rows, 201.3ms)
```sql
-- Exam
-- Base: district, year, calc £/m2. Filter year, property type etc
-- Agg: group by district x year
-- Windows: LAG median price, calc change, rank year change
-- Final:  CASE best year
-- Final grain: 1 row per district

WITH base AS (
SELECT 
    district, 
    year, 
    price_paid / total_floor_area AS ppsqm
FROM
    sales
WHERE year BETWEEN 2015 AND 2024 
    AND property_subtype <> 'O' 
    AND total_floor_area IS NOT NULL
    AND total_floor_area BETWEEN 15 AND 500),

agg AS (SELECT 
    district, 
    year, 
    MEDIAN(ppsqm) AS median_ppsqm
FROM
    base
GROUP BY
    district,
    year
HAVING COUNT(ppsqm) >= 30),

win AS (SELECT 
    district, 
    year, 
    median_ppsqm,
    LAG(median_ppsqm) OVER(PARTITION BY district ORDER BY year) AS prev_median_ppsqm,
    ROUND(100 * (median_ppsqm - (LAG(median_ppsqm) OVER(PARTITION BY district ORDER BY year))) / LAG(median_ppsqm) OVER(PARTITION BY district ORDER BY year), 1) AS yoy_pct
FROM
    agg),
    
win2 AS (SELECT 
    district, 
    year, 
    median_ppsqm,
    prev_median_ppsqm,
    yoy_pct,
    RANK() OVER(PARTITION BY district ORDER BY yoy_pct DESC, year ASC) AS year_rank
FROM
    win)

SELECT 
    district, 
    year AS best_year, 
    ROUND(median_ppsqm, 0) AS median_ppsqm,
    ROUND(prev_median_ppsqm, 0) AS prev_median_ppsqm,
    yoy_pct
FROM
    win2
WHERE year_rank = 1
;
```

---

### [14:55:33] Exam — +116.7s since last run | ERROR (82.5ms)

> **Error:** `Parser Error: syntax error at or near "SELECT" | LINE 32:     SELECT`
```sql
-- Exam
-- Base: district, year, calc £/m2. Filter year, property type etc
-- Agg: group by district x year
-- Windows: LAG median price, calc change, rank year change
-- Final:  CASE best year
-- Final grain: 1 row per district

WITH base AS (
SELECT 
    district, 
    year, 
    price_paid / total_floor_area AS ppsqm
FROM
    sales
WHERE year BETWEEN 2015 AND 2024 
    AND property_subtype <> 'O' 
    AND total_floor_area IS NOT NULL
    AND total_floor_area BETWEEN 15 AND 500),

agg AS (SELECT 
    district, 
    year, 
    MEDIAN(ppsqm) AS median_ppsqm
FROM
    base
GROUP BY
    district,
    year
HAVING COUNT(ppsqm) >= 30),

-- win AS (
    SELECT 
    district, 
    year, 
    median_ppsqm,
    LAG(median_ppsqm) OVER(PARTITION BY district ORDER BY year) AS prev_median_ppsqm,
    ROUND(100 * (median_ppsqm - (LAG(median_ppsqm) OVER(PARTITION BY district ORDER BY year))) / LAG(median_ppsqm) OVER(PARTITION BY district ORDER BY year), 1) AS yoy_pct
FROM
    agg
--     ),
    
-- win2 AS (SELECT 
--     district, 
--     year, 
--     median_ppsqm,
--     prev_median_ppsqm,
--     yoy_pct,
--     RANK() OVER(PARTITION BY district ORDER BY yoy_pct DESC, year ASC) AS year_rank
-- FROM
--     win)

-- SELECT 
--     district, 
--     year AS best_year, 
--     ROUND(median_ppsqm, 0) AS median_ppsqm,
--     ROUND(prev_median_ppsqm, 0) AS prev_median_ppsqm,
--     yoy_pct
-- FROM
--     win2
-- WHERE year_rank = 1
;
```

---

### [14:55:44] Exam — +10.9s since last run | SUCCESS (50 rows, 105.1ms)
```sql
-- Exam
-- Base: district, year, calc £/m2. Filter year, property type etc
-- Agg: group by district x year
-- Windows: LAG median price, calc change, rank year change
-- Final:  CASE best year
-- Final grain: 1 row per district

WITH base AS (
SELECT 
    district, 
    year, 
    price_paid / total_floor_area AS ppsqm
FROM
    sales
WHERE year BETWEEN 2015 AND 2024 
    AND property_subtype <> 'O' 
    AND total_floor_area IS NOT NULL
    AND total_floor_area BETWEEN 15 AND 500),

agg AS (SELECT 
    district, 
    year, 
    MEDIAN(ppsqm) AS median_ppsqm
FROM
    base
GROUP BY
    district,
    year
HAVING COUNT(ppsqm) >= 30)

-- win AS (
    SELECT 
    district, 
    year, 
    median_ppsqm,
    LAG(median_ppsqm) OVER(PARTITION BY district ORDER BY year) AS prev_median_ppsqm,
    ROUND(100 * (median_ppsqm - (LAG(median_ppsqm) OVER(PARTITION BY district ORDER BY year))) / LAG(median_ppsqm) OVER(PARTITION BY district ORDER BY year), 1) AS yoy_pct
FROM
    agg
--     ),
    
-- win2 AS (SELECT 
--     district, 
--     year, 
--     median_ppsqm,
--     prev_median_ppsqm,
--     yoy_pct,
--     RANK() OVER(PARTITION BY district ORDER BY yoy_pct DESC, year ASC) AS year_rank
-- FROM
--     win)

-- SELECT 
--     district, 
--     year AS best_year, 
--     ROUND(median_ppsqm, 0) AS median_ppsqm,
--     ROUND(prev_median_ppsqm, 0) AS prev_median_ppsqm,
--     yoy_pct
-- FROM
--     win2
-- WHERE year_rank = 1
;
```

---

### [14:56:47] Exam — +63.1s since last run | ERROR (75.2ms)

> **Error:** `Parser Error: syntax error at or near "WITH" | LINE 48:     win`
```sql
-- Exam
-- Base: district, year, calc £/m2. Filter year, property type etc
-- Agg: group by district x year
-- Windows: LAG median price, calc change, rank year change
-- Final:  CASE best year
-- Final grain: 1 row per district

WITH base AS (
SELECT 
    district, 
    year, 
    price_paid / total_floor_area AS ppsqm
FROM
    sales
WHERE year BETWEEN 2015 AND 2024 
    AND property_subtype <> 'O' 
    AND total_floor_area IS NOT NULL
    AND total_floor_area BETWEEN 15 AND 500),

agg AS (SELECT 
    district, 
    year, 
    MEDIAN(ppsqm) AS median_ppsqm
FROM
    base
GROUP BY
    district,
    year
HAVING COUNT(ppsqm) >= 30),

win AS (SELECT 
    district, 
    year, 
    median_ppsqm,
    LAG(median_ppsqm) OVER(PARTITION BY district ORDER BY year) AS prev_median_ppsqm,
    ROUND(100 * (median_ppsqm - (LAG(median_ppsqm) OVER(PARTITION BY district ORDER BY year))) / LAG(median_ppsqm) OVER(PARTITION BY district ORDER BY year), 1) AS yoy_pct
FROM
    agg),
    
win2 AS (SELECT 
    district, 
    year, 
    median_ppsqm,
    prev_median_ppsqm,
    yoy_pct,
    RANK() OVER(PARTITION BY district ORDER BY yoy_pct DESC, year ASC) AS year_rank
FROM
    win
WITH prev_median_ppsqm IS NOT NULL)

SELECT 
    district, 
    year AS best_year, 
    ROUND(median_ppsqm, 0) AS median_ppsqm,
    ROUND(prev_median_ppsqm, 0) AS prev_median_ppsqm,
    yoy_pct
FROM
    win2
WHERE year_rank = 1
;
```

---

### [14:57:03] Exam — +15.9s since last run | SUCCESS (5 rows, 126.2ms)
```sql
-- Exam
-- Base: district, year, calc £/m2. Filter year, property type etc
-- Agg: group by district x year
-- Windows: LAG median price, calc change, rank year change
-- Final:  CASE best year
-- Final grain: 1 row per district

WITH base AS (
SELECT 
    district, 
    year, 
    price_paid / total_floor_area AS ppsqm
FROM
    sales
WHERE year BETWEEN 2015 AND 2024 
    AND property_subtype <> 'O' 
    AND total_floor_area IS NOT NULL
    AND total_floor_area BETWEEN 15 AND 500),

agg AS (SELECT 
    district, 
    year, 
    MEDIAN(ppsqm) AS median_ppsqm
FROM
    base
GROUP BY
    district,
    year
HAVING COUNT(ppsqm) >= 30),

win AS (SELECT 
    district, 
    year, 
    median_ppsqm,
    LAG(median_ppsqm) OVER(PARTITION BY district ORDER BY year) AS prev_median_ppsqm,
    ROUND(100 * (median_ppsqm - (LAG(median_ppsqm) OVER(PARTITION BY district ORDER BY year))) / LAG(median_ppsqm) OVER(PARTITION BY district ORDER BY year), 1) AS yoy_pct
FROM
    agg),
    
win2 AS (SELECT 
    district, 
    year, 
    median_ppsqm,
    prev_median_ppsqm,
    yoy_pct,
    RANK() OVER(PARTITION BY district ORDER BY yoy_pct DESC, year ASC) AS year_rank
FROM
    win
WHERE prev_median_ppsqm IS NOT NULL)

SELECT 
    district, 
    year AS best_year, 
    ROUND(median_ppsqm, 0) AS median_ppsqm,
    ROUND(prev_median_ppsqm, 0) AS prev_median_ppsqm,
    yoy_pct
FROM
    win2
WHERE year_rank = 1
;
```

---

### [15:04:16] Exam — +433.0s since last run | ERROR (175.3ms)

> **Error:** `Parser Error: syntax error at or near "LAG" | LINE 38:     LAG(year) OVER(PARTITION BY district ORDER BY year) AS...`
```sql
-- Exam
-- Base: district, year, calc £/m2. Filter year, property type etc
-- Agg: group by district x year
-- Windows: LAG median price, calc change, rank year change
-- Final:  CASE best year
-- Final grain: 1 row per district

SELECT DISTINCT property_subtype FROM sales;


WITH base AS (
SELECT 
    district, 
    year, 
    price_paid / total_floor_area AS ppsqm
FROM
    sales
WHERE year BETWEEN 2015 AND 2024 
    AND property_subtype <> 'O'
    AND total_floor_area BETWEEN 15 AND 500),

agg AS (SELECT 
    district, 
    year, 
    MEDIAN(ppsqm) AS median_ppsqm
FROM
    base
GROUP BY
    district,
    year
HAVING COUNT(ppsqm) >= 30),

win AS (SELECT 
    district, 
    year, 
    median_ppsqm,
    LAG(median_ppsqm) OVER(PARTITION BY district ORDER BY year) AS prev_median_ppsqm
    LAG(year) OVER(PARTITION BY district ORDER BY year) AS prev_year,
    100 * (median_ppsqm - (LAG(median_ppsqm) OVER(PARTITION BY district ORDER BY year))) / LAG(median_ppsqm) OVER(PARTITION BY district ORDER BY year) AS yoy_pct
FROM
    agg),
    
win2 AS (SELECT 
    district, 
    year, 
    median_ppsqm,
    prev_median_ppsqm,
    yoy_pct,
    RANK() OVER(PARTITION BY district ORDER BY yoy_pct DESC, year ASC) AS year_rank
FROM
    win
WHERE year - prev_year = 1 AND prev_median_ppsqm IS NOT NULL)

SELECT 
    district, 
    year AS best_year, 
    ROUND(median_ppsqm, 0) AS median_ppsqm,
    ROUND(prev_median_ppsqm, 0) AS prev_median_ppsqm,
    ROUND(yoy_pct, 1) AS yoy_pct
FROM
    win2
WHERE year_rank = 1
ORDER BY yoy_pct DESC
;
```

---

### [15:04:31] Exam — +15.3s since last run | SUCCESS (11 rows, 166.8ms)
```sql
-- Exam
-- Base: district, year, calc £/m2. Filter year, property type etc
-- Agg: group by district x year
-- Windows: LAG median price, calc change, rank year change
-- Final:  CASE best year
-- Final grain: 1 row per district

SELECT DISTINCT property_subtype FROM sales;


WITH base AS (
SELECT 
    district, 
    year, 
    price_paid / total_floor_area AS ppsqm
FROM
    sales
WHERE year BETWEEN 2015 AND 2024 
    AND property_subtype <> 'O'
    AND total_floor_area BETWEEN 15 AND 500),

agg AS (SELECT 
    district, 
    year, 
    MEDIAN(ppsqm) AS median_ppsqm
FROM
    base
GROUP BY
    district,
    year
HAVING COUNT(ppsqm) >= 30),

win AS (SELECT 
    district, 
    year, 
    median_ppsqm,
    LAG(median_ppsqm) OVER(PARTITION BY district ORDER BY year) AS prev_median_ppsqm,
    LAG(year) OVER(PARTITION BY district ORDER BY year) AS prev_year,
    100 * (median_ppsqm - (LAG(median_ppsqm) OVER(PARTITION BY district ORDER BY year))) / LAG(median_ppsqm) OVER(PARTITION BY district ORDER BY year) AS yoy_pct
FROM
    agg),
    
win2 AS (SELECT 
    district, 
    year, 
    median_ppsqm,
    prev_median_ppsqm,
    yoy_pct,
    RANK() OVER(PARTITION BY district ORDER BY yoy_pct DESC, year ASC) AS year_rank
FROM
    win
WHERE year - prev_year = 1 AND prev_median_ppsqm IS NOT NULL)

SELECT 
    district, 
    year AS best_year, 
    ROUND(median_ppsqm, 0) AS median_ppsqm,
    ROUND(prev_median_ppsqm, 0) AS prev_median_ppsqm,
    ROUND(yoy_pct, 1) AS yoy_pct
FROM
    win2
WHERE year_rank = 1
ORDER BY yoy_pct DESC
;
```

---

### [15:05:30] Exam — +59.2s since last run | SUCCESS (13 rows, 264.6ms)
```sql
-- Exam
-- Base: district, year, calc £/m2. Filter year, property type etc
-- Agg: group by district x year
-- Windows: LAG median price, calc change, rank year change
-- Final:  CASE best year
-- Final grain: 1 row per district

SELECT DISTINCT property_subtype FROM sales;


WITH base AS (
SELECT 
    district, 
    year, 
    price_paid / total_floor_area AS ppsqm
FROM
    sales
WHERE year BETWEEN 2015 AND 2024 
    AND property_subtype <> 'O'
    AND total_floor_area BETWEEN 15 AND 500),

agg AS (SELECT 
    district, 
    year, 
    MEDIAN(ppsqm) AS median_ppsqm
FROM
    base
GROUP BY
    district,
    year
HAVING COUNT(ppsqm) >= 30),

win AS (SELECT 
    district, 
    year, 
    median_ppsqm,
    LAG(median_ppsqm) OVER(PARTITION BY district ORDER BY year) AS prev_median_ppsqm,
    LAG(year) OVER(PARTITION BY district ORDER BY year) AS prev_year,
    100 * (median_ppsqm - (LAG(median_ppsqm) OVER(PARTITION BY district ORDER BY year))) / LAG(median_ppsqm) OVER(PARTITION BY district ORDER BY year) AS yoy_pct
FROM
    agg),
    
win2 AS (SELECT 
    district, 
    year, 
    median_ppsqm,
    prev_median_ppsqm,
    yoy_pct,
    RANK() OVER(PARTITION BY district ORDER BY yoy_pct DESC, year ASC) AS year_rank
FROM
    win
WHERE year - prev_year = 1 AND prev_median_ppsqm IS NOT NULL)

SELECT 
    district, 
    year AS best_year, 
    ROUND(median_ppsqm, 0) AS median_ppsqm,
    ROUND(prev_median_ppsqm, 0) AS prev_median_ppsqm,
    ROUND(yoy_pct, 1) AS yoy_pct
FROM
    win2
WHERE year_rank = 1
ORDER BY yoy_pct DESC
;
SELECT COUNT(*), COUNT(DISTINCT unique_id) FROM sales;
```

---

### [15:24:56] Exam — +1165.8s since last run | SUCCESS (5 rows, 115.6ms)
```sql
-- Exam
-- Base: district, year, calc £/m2. Filter year, property type etc
-- Agg: group by district x year
-- Windows: LAG median price, calc change, rank year change
-- Final grain: 1 row per district

WITH base AS (
SELECT 
    district, 
    year, 
    price_paid / total_floor_area AS ppsqm
FROM
    sales
WHERE year BETWEEN 2015 AND 2024 
    AND property_subtype <> 'O'
    AND total_floor_area BETWEEN 15 AND 500),

agg AS (SELECT 
    district, 
    year, 
    MEDIAN(ppsqm) AS median_ppsqm
FROM
    base
GROUP BY
    district,
    year
HAVING COUNT(ppsqm) >= 30),

win AS (SELECT 
    district, 
    year, 
    median_ppsqm,
    LAG(median_ppsqm) OVER(PARTITION BY district ORDER BY year) AS prev_median_ppsqm,
    LAG(year) OVER(PARTITION BY district ORDER BY year) AS prev_year,
    100 * (median_ppsqm - (LAG(median_ppsqm) OVER(PARTITION BY district ORDER BY year))) / LAG(median_ppsqm) OVER(PARTITION BY district ORDER BY year) AS yoy_pct
FROM
    agg),
    
win2 AS (SELECT 
    district, 
    year, 
    median_ppsqm,
    prev_median_ppsqm,
    yoy_pct,
    RANK() OVER(PARTITION BY district ORDER BY yoy_pct DESC, year ASC) AS year_rank
FROM
    win
WHERE year - prev_year = 1 AND prev_median_ppsqm IS NOT NULL)

SELECT 
    district, 
    year AS best_year, 
    ROUND(median_ppsqm, 0) AS median_ppsqm,
    ROUND(prev_median_ppsqm, 0) AS prev_median_ppsqm,
    ROUND(yoy_pct, 1) AS yoy_pct
FROM
    win2
WHERE year_rank = 1
ORDER BY yoy_pct DESC
;
```

---

