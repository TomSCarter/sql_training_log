# Day 1

```
Use the row-level joined Land Registry + EPC table that your cleaning pipeline writes out: the one with a row per matched sale, before `prepare_data.py` aggregates it. The deployed dashboard tables are too small and already aggregated, so they won't test much. Query the Parquet file directly with `read_parquet()` rather than loading it into a table first. That's one less step, and it's how you'd work in an exam environment.

I don't know your exact column names, so the problem below describes the columns you need. Map them to your own and write that mapping as a comment at the top of your query before starting the timer.

---

**Problem: best year for £/m² growth by district (target: under 15 minutes)**

An investor wants to know, for each Oxfordshire district, which year saw the biggest rise in typical price per square metre.

Data rules:
- Use sales from 2015 to 2024 inclusive.
- Exclude property type "Other" (Land Registry type O).
- Exclude sales with a missing floor area, or a floor area outside 15–500 m².
- £/m² is price divided by EPC total floor area. "Typical" means the median.
- A district-year with fewer than 30 sales is unreliable. Treat it as having no value.

Definition:
- The year-on-year change for a district-year is the % change in median £/m² from the immediately preceding calendar year. If either year has no value (no sales, or under the 30-sale threshold), that district-year has no year-on-year change.

Output, one row per district:

| column | description |
|---|---|
| `district` | district name |
| `best_year` | year with the largest year-on-year % rise |
| `median_ppsqm` | median £/m² in that year, rounded to the nearest pound |
| `prev_median_ppsqm` | median £/m² in the preceding year, rounded to the nearest pound |
| `yoy_pct` | % change, rounded to 1 decimal place |

Further rules:
- If two years tie for a district, take the earlier year.
- Districts with no valid year-on-year change at all are excluded.
- Sort by `yoy_pct` descending.

---

**Checking without an answer key.** These checks don't confirm the answer, but they catch most mistakes:
- Every district in your output should have `best_year` between 2016 and 2024.
- Recomputing `yoy_pct` by hand from `median_ppsqm` and `prev_median_ppsqm` should give the same value for every row.
- Pick one district and list all its yearly medians and counts in a separate query. Then confirm by eye that the year you chose is the right one and that no year has been compared across a gap.

Log your time, and how many rule violations you found when you checked. Then paste your query here, and I'll review it with each point labelled as must-fix or optional.

If you finish well inside the target, ask for a second problem. I'll make the next one a self-join on repeat sales of the same property, which will also need your pipeline's property identifier.
```
My initial answer (27min):


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

Corrected:

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
```
**Where the time went**

From your first run (14:35) to the working version (14:57) is about 22 minutes. That splits into roughly:
- 5 minutes on the base query.
- 4 minutes on the aggregation and threshold.
- 7 minutes on the window section.
- 4 minutes on final rounding and the NULL filter.

Building in small runs and checking the 50-row count (5 districts × 10 years) was sound. The four syntax errors each took 8 to 16 seconds to fix once you saw the message, so they weren't the problem. The real costs were:
- **The 14:55 detour.** You commented out a CTE to see the `win` output. Ending the chain with `SELECT * FROM win;` shows any stage in seconds, without editing the structure.
- **The gap rule.** It was in the spec but not in your plan comment, so you found it only in review. Before coding, map every rule in the spec to a line in your header comment. It takes a minute and would have caught both the gap rule and the NULL question.
- **Repeated `LAG` calls.** You typed the same window clause three times. DuckDB lets you name it once:

    ```sql
    SELECT LAG(val) OVER w AS prev_val, LAG(yr) OVER w AS prev_yr
    FROM t
    WINDOW w AS (PARTITION BY grp ORDER BY yr);
    ```

Your 7 minutes on the revision (14:57 to 15:04) was good. Log it as about 22 minutes to a working version, about 29 to a corrected one, and not counting the set-up.
```