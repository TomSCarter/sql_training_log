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