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