# Unit 5: Connecting the Tables

**Theme 5: Airline Booking**
**Database:** `ex603_data` loaded from `airline.sql` (PostgreSQL)
**Queries:** `queries/unit5/q5_1.sql`, `queries/unit5/q5_2.sql`, `queries/unit5/q5_3.sql`
**Author:** Ayotola O. Jinadu

Role mapping: actor = `passengers`, producer = `flights`, event = `bookings`, catalog = `airports`, junction = `flight_routes`.

Failure state, carried over from Units 3 and 4: a booking fails when the passenger does not show up (`cancellation_reason = 'Passenger no show'`). Platform rate: 12 of 192, or 6.3%.

Flights flagged in Unit 4:

| Flight | Bookings | No-shows | Rate | Note |
| --- | --- | --- | --- | --- |
| VN202 | 16 | 3 | 18.8% | The only high-volume outlier |
| VN203 | 13 | 2 | 16.7% | Marked inactive |
| VN204 | 6 | 1 | 16.7% | Too few bookings to judge |

> Lines marked **[confirm]** are still to be checked against the screenshots. The rest comes from the Unit 4 results and the dataset schema.

---

## Task 5.1: Connect producers to their data

### Question 1: The three-table join (5.1a)

`bookings` is joined to `passengers` on `passenger_id` and to `flights` on `flight_id`. Each row shows who booked, which flight, when it was booked, and how it ended. The narrowed version keeps only the no-shows on VN202, VN203 and VN204, which should come to 6 rows (3 + 2 + 1). **[confirm]**

**What feature could use this join?** A **flight manifest and no-show report** for the operations team. For any flight, it would list each passenger by name with their home country, when they booked, whether they checked in (`checked_in_at`), and how the booking ended. On its own the bookings table only holds IDs. The join turns "flight 2, passenger 17" into a name and a flight number that a gate agent or route manager can act on. Customer service could use the same join for a passenger's booking history page.

### Question 2: Junction traversal (5.1b)

The query goes from `flights` through `flight_routes` to `airports`, and returns the airports (`iata_code`) each flight serves. The flagged flights are labelled. A summary query counts how many flagged flights serve each airport.

Finding: **[confirm from screenshot: which airport codes VN202, VN203 and VN204 serve, and whether they share one]**

**Why the junction table matters.** A flight can serve more than one airport, and an airport is served by many flights. That is a many-to-many relationship, and a single foreign key cannot store it. `flight_routes` holds one row per flight-airport pair, plus `effective_from` for when that pairing started. Without it there are two bad options. One is to put airport columns on `flights` (`airport_1`, `airport_2` ...), which caps how many airports a flight can have and means searching several columns to find every flight at one airport. The other is to store airport codes as a text list, which cannot be joined or checked against `airports`. Either way, "which flagged flights share an airport" becomes much harder to answer and much easier to get wrong.

### Question 3: Self join (5.1c)

`flights` is joined to itself. Each flagged flight (`f1`) is paired with every other flight from the same `origin_country` (`f2`). The two are compared on seat capacity, first scheduled date, active status, bookings and no-shows.

Finding: **[confirm from screenshot: whether the flagged flights differ from their same-country peers on capacity, start date, active status or booking volume]**

What the data already shows: VN203 is inactive, so its no-shows may come from a period when the flight was being wound down. VN204 has only 6 bookings, so one no-show is enough to give it a high rate. VN202 is the one where the rate is both high and based on enough bookings to take seriously.

---

## Task 5.2: Find records that joins may exclude

### Part A: INNER JOIN vs LEFT JOIN

| Query | Distinct flights returned |
| --- | --- |
| LEFT JOIN `flights` to `bookings` | 15 |
| INNER JOIN `flights` to `bookings` | 13 |
| **Excluded by the inner join** | **2** |

Counted with `COUNT(DISTINCT f.flight_id)` so that a flight with 21 bookings counts once, not 21 times.

**Which producers were excluded?** **VN214** and **VN215**. **[confirm their flight_id values from 5.2A-4]** Neither has a single row in `bookings`. An inner join only keeps a flight when a matching booking exists, so these two drop out without any warning. The left join keeps them, with NULL on the booking side and a count of 0.

### Part B: RIGHT JOIN and FULL OUTER JOIN

The RIGHT JOIN swaps the table order (`bookings RIGHT JOIN flights`) so `flights` is the side kept in full. To check that it really matches the left join, query 5.2B-2 runs `EXCEPT` in both directions: rows in LEFT that are not in RIGHT, and rows in RIGHT that are not in LEFT. Both came back as 0, and both results have 15 rows, so they are identical. **[confirm]**

The FULL OUTER JOIN keeps unmatched rows from **both** sides and labels each row as matched, flight with no bookings, or booking with no flight. Result: 200 matched rows, 2 flights with no bookings, 0 bookings with no flight. **[confirm]** There are no orphan bookings because the foreign key on `bookings.flight_id` blocks them.

**What a full outer join shows that a left or right join does not.** A left join can find flights with no bookings, but not bookings with no valid flight. A right join, written the other way round, can find one but not the other. A full outer join checks both directions in one query. That makes it a data-integrity check as well as a report. Here it confirmed the bookings side is clean. On a dataset without that foreign key, the same query would catch bookings that point at a deleted or mistyped flight.

### Part C: NOT EXISTS vs EXCEPT

Both return the same two flights, VN214 and VN215. **[confirm]** `NOT EXISTS` works row by row: for each flight, it checks whether any booking points at it, and stops as soon as it finds one. `EXCEPT` works on whole sets: it takes every `flight_id` in `flights`, removes every `flight_id` that appears in `bookings`, and also removes duplicates. One practical difference: `NOT EXISTS` can return any columns from `flights` directly, while `EXCEPT` only compares the columns listed, so getting the flight number back needs a second step.

### Write-up

**What does it mean when a producer has no events?** The flight exists in the system, but nobody has ever booked a seat on it. The data shows that much. It does not show *why*. Possible explanations, all of which need checking:

- The flight is new, or scheduled for the future, and has not opened for sale yet. `first_scheduled_on` is the first thing to check. **[confirm dates]**
- The flight has been retired but its record was kept. `is_active` would show this. **[confirm]**
- It is on sale but not visible, for example because of a pricing, distribution or search setup problem.
- It serves a route nobody wants, at least at the current price or time.
- It is test or placeholder data that was never cleaned up.

**How an inner-join report gives leadership an incomplete picture.** Every Unit 4 report used an inner join from `bookings` to `flights`. So every one of them described 13 flights and quietly treated that as the whole network. Leadership would see per-flight averages, rates and regional totals with no sign that 2 of 15 flights, about 13% of what the platform offers, had produced nothing. It also makes the platform look healthier: averages over flights that sell are higher than averages over all flights. The report is not wrong about the flights it covers. It just leaves out the ones that are failing most completely.

**Why leadership would want to find never-active producers.** Every flight on the platform costs something to keep: it is scheduled, an aircraft (`tail_number`) and seats (`seat_capacity`) are set aside for it, and it sits in the catalog. A flight that never sells uses those resources and brings in nothing. It can also point to a problem in the system that affects other flights too.

**What action leadership could take.** Check VN214 and VN215 one by one. If they are scheduled for the future, leave them alone and watch them. If they are retired, mark them inactive so they stop appearing as part of the network. If they are on sale and still not selling, look at visibility and pricing first, and set a deadline after which the flight is cut. This is a separate decision from VN202, which sells but has passengers not showing up. Details are in `unit5-finding.md`.

---

## Task 5.3: Join performance and execution plans

### Part A: CROSS JOIN

| | Rows |
| --- | --- |
| `flights` | 15 |
| `airports` | **[confirm]** |
| Expected product (flights × airports) | **[confirm]** |
| Actual CROSS JOIN rows | **[confirm]** |
| `matches` | true **[confirm]** |

The CROSS JOIN pairs every flight with every airport, so the row count is the product of the two table counts. Query 5.3A-1 puts both counts, the product and the actual count side by side in one result, so the multiplication can be checked in one screenshot.

**When a Cartesian product is useful on this platform.** Building a **coverage grid**: every flight against every airport, with a flag showing which pairings are real routes (query 5.3A-2). That is how you list what does *not* exist, such as airports a flight does not serve, or empty cells in a flight × month report that should show 0 instead of being missing. The Unit 4 baseline query also used a deliberate `CROSS JOIN` to attach one baseline row to every flight.

**When it signals a mistake.** When it was not intended. Usually it means a missing or wrong `ON` condition, or a table listed in `FROM` with no join condition. On this data, `bookings` × `passengers` would turn 200 bookings into 6,000 rows. Every `SUM` and `COUNT` on top of that would be inflated, and the query would still run without an error. The warning sign is a row count close to the product of two table sizes.

### Part B: Execution plan for the 5.1a three-table join

Full plan: **[paste EXPLAIN (ANALYZE, BUFFERS) output here as a code block]**

```
[paste plan]
```

**Join algorithms PostgreSQL chose:** **[confirm from plan]** On tables this small (200 bookings, 30 passengers, 15 flights) I expect **Hash Join** for both joins, with a **Seq Scan** on each table and a **Sort** at the end for `ORDER BY booked_at`.

**What in the plan explains the choice:**

- **Row estimates** (`rows=`) on each scan. The smaller tables, `passengers` and `flights`, are read whole and built into in-memory hash tables. Then `bookings` is scanned once and each row is looked up in those hash tables.
- **Seq Scan instead of Index Scan.** Primary keys are indexed (see the 5.3B-3 index list), but with every row needed from tables this small, reading them straight through costs less than jumping around an index.
- **Cost figures** (`cost=start..total`). The planner picks the cheapest total cost it estimates. **[confirm numbers]**
- **Actual vs estimated rows** (from ANALYZE). If they match closely, the planner's statistics are good and its choice can be trusted.
- **Sort node.** Shows the sort ran in memory (`Sort Method: quicksort`) because nothing returns the rows already in `booked_at` order.

**Why it is useful to understand the join algorithm.** The same SQL can be fast or slow depending on how it is run. If a report slows down, the plan shows whether the cause is a large table being scanned, a hash table that no longer fits in memory, or a bad row estimate. It also shows which index would actually help, instead of guessing.

**What might become less efficient as the data grows.** `bookings` is the table that grows. Passengers and flights grow much more slowly. With no filter, the query still reads every booking, so the scan of `bookings` and the final **Sort** grow in step with it. Once the sort no longer fits in `work_mem`, it spills to disk (`Sort Method: external merge`), and that is usually the first visible slowdown. If the report is filtered (one flight, one passenger, a date range), the plan should move to a Nested Loop or Index Scan, but only if `bookings.flight_id`, `bookings.passenger_id` or `booked_at` are indexed. **[confirm from the 5.3B-3 index list whether they are]**

**What changes would make another algorithm better:**

- **A selective filter plus an index on the foreign key.** `WHERE f.flight_number = 'VN202'` with an index on `bookings.flight_id` points to a **Nested Loop** with an index lookup: find the one flight, then fetch only its bookings.
- **Both sides already sorted on the join key**, for example from indexes on both join columns at large volume. That points to a **Merge Join**, which walks two sorted lists side by side with no hash table.
- **Much larger tables.** Hash Join still works well, but once the hash table no longer fits in memory it splits into batches on disk. At that point, raising `work_mem` or adding indexes changes the plan.
- **Out-of-date statistics.** If `ANALYZE` has not run since a large load, the planner may underestimate row counts and pick a Nested Loop that then runs thousands of times.

---

## Reflection

The plan for my three-table join was shaped mostly by size. `bookings` has 200 rows, `passengers` 30 and `flights` 15, and nothing filtered them. So PostgreSQL read each table in full, built hash tables from the two smaller ones and matched bookings against them. With every row needed, an index lookup per row would only have added work. **[adjust if your plan shows a different algorithm]**

Several changes would move it to a different algorithm. The first is a selective filter. If the report only needed one flight's bookings and `bookings.flight_id` were indexed, the planner would switch to a Nested Loop with an index lookup, because it would only touch a handful of rows instead of all of them. Without that index, the same filter still means scanning the whole bookings table. The second is growth. As bookings reach the millions, a Hash Join is still a good choice, but the hash table and the final sort may stop fitting in memory and spill to disk, which is where the slowdown would first show up. The third is how many rows match. If the inputs were already sorted on the join key, for example through indexes on both sides, a Merge Join could beat the hash approach because it needs no extra memory.

A query is not slow or fast on its own. The plan depends on the data and indexes around it, so it needs checking again as the platform grows.
