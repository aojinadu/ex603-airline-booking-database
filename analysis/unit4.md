# Unit 4: From Rows to Insight

**Theme 5: Airline Booking**
**Database:** `ex603_data` loaded from `airline.sql` (PostgreSQL)
**Queries:** `queries/unit4/q4_1.sql`, `queries/unit4/q4_2.sql`
**Author:** Ayotola O. Jinadu

Role mapping: actor = `passengers`, producer = `flights`, event = `bookings`, metric = `fare_paid`.

**Failure state.** Carried over from Unit 3: a booking fails when the passenger does not show up (`cancellation_reason = 'Passenger no show'`). The rate leaves out bookings the passenger cancelled themselves, and counts a blank `cancellation_reason` as "not a passenger cancellation", which is the fix from Unit 3. On that definition the platform rate is 12 out of 192, or 6.3%.

---

## Task 4.1: Measure the platform

### What the queries showed

**4.1a Baseline.** 200 bookings, 3,628.19 in fares, an average fare of 18.14, a minimum of 0.00, a maximum of 70.86, and 30 distinct passengers.

The minimum of 0.00 needed a closer look, because a seat that was sold should not have cost nothing. The follow-up query shows that every one of the 34 cancelled bookings has a fare of exactly zero, and no confirmed or disputed booking does. So the zero is not random bad data: cancelled bookings are being stored with the fare wiped rather than with the original fare plus a refund. That has two effects. The 18.14 platform average understates what a real booking pays (confirmed bookings average 21.92), and the original price of every cancelled booking is gone, so nobody can say how much revenue no-shows actually cost.

**4.1b Per producer.** 13 of the 15 flights have bookings; VN214 and VN215 have none. Volume runs from 21 bookings (VN206) to 6 (VN204), and the average fare from 23.06 (VN205) to 11.94 (VN211). The low averages line up with the flights that have more cancellations, because each cancellation adds a zero to the average. VN211's low average is partly that and not only cheaper tickets.

**4.1c HAVING threshold.** I used `HAVING COUNT(*) >= 15`. The platform rate is about 6%, so a flight needs around 15 bookings before even one no-show is expected. Below that, one no-show moves a flight's rate by 7 points or more, which is noise rather than a signal. 15 is also close to the platform average of 15.4 bookings per flight, so the filter keeps the flights carrying a typical or larger share of the traffic. Eight flights qualify. Seven of them sit between 0% and 6.7%. VN202 is the exception at 18.8% (3 of 16).

**4.1d Two dimensions.** Region (`flights.origin_country`) by booking outcome gives 12 rows, one per combination that occurs. Korea has 6 of the 10 disputed bookings. Japan has the most cancellations (13 of its 53 bookings). Vietnam has one flight, VN210, and every one of its 19 bookings was confirmed.

### Write-up

**Who acts on the per-producer breakdown.** The route manager responsible for each flight. They own the flight's schedule and performance, they were the person who questioned the dashboard in Unit 3, and they are the one who can actually change something on a flight: overbooking policy, check-in reminders, or how a route is sold.

**What the aggregate hides.**

- *An average conceals its distribution.* The 18.14 average fare is a blend of two very different groups: 166 bookings that paid real fares (around 22) and 34 cancelled bookings sitting at zero. No booking actually costs 18.14. In the same way, the 6.3% platform rate is an average over flights that range from 0% to 18.8%. Four flights have no no-shows at all, and one high-volume flight has three times the platform rate.
- *A count conceals who is counted.* "200 bookings" sounds like 200 travellers, but it is 30 passengers, one of whom (passenger 1) holds 13 bookings and two of the 12 no-shows. The count of bookings per flight also says nothing about how full the flight is: VN206 has the most bookings but only 90 seats, while VN202 has 320. And the per-flight counts include two flights marked inactive, VN203 and VN209, which still carry 27 bookings between them, including 3 no-shows.

**What I would need to see next.**

1. The original fare on cancelled bookings (or a separate refunds table), so the cost of no-shows can be put in money and not only in counts.
2. Bookings per flight measured against seat capacity and over time (by month), to see whether VN202's no-shows are a recent trend or spread out.
3. A passenger-level view of no-shows, to check whether a few repeat passengers drive the rate. For VN202 the three no-shows came from three different passengers across the year, which points at the flight rather than at one traveller.
4. An explanation for bookings on inactive flights. Either the `is_active` flag is out of date or bookings were taken on flights that were no longer running.

---

## Task 4.2: Build the breakdown leadership asked for

### Part A: Two numbers in one pass

The query uses `SUM(CASE WHEN ... THEN 1 ELSE 0 END)` inside a single `GROUP BY` over `bookings`, with no `WHERE` clause, so every booking is read once and sorted into the right columns.

The two questions it answers side by side, for each flight:

1. **How many bookings did this flight take in total?** (`total_bookings`)
2. **How many of those bookings ended with the passenger not showing up?** (`no_show_bookings`)

A third conditional sum (`bookings_in_rate`) gives the correct denominator from the same pass, so the rate comes out in the same row. The outliers are VN202 (3 of 16, 18.8%), VN203 (2 of 12, 16.7%, on a flight marked inactive) and VN204 (1 of 6, 16.7%, but too few bookings to read anything into).

### Part B: Subtotals and a grand total

The query uses `GROUP BY ROLLUP (f.origin_country)`. Because the flight is not in the ROLLUP list, no per-flight detail rows are produced: only the region rows and the platform row.

**Which rows are which.**

| `row_type` | `region` | What it is |
| --- | --- | --- |
| Region subtotal | Japan, Korea, Singapore, Thailand, Vietnam | One row per region, totalled across every flight based there (`GROUPING(origin_country) = 0`). |
| Platform grand total | ALL REGIONS | The last row: all 13 flights, 200 bookings, 12 no-shows, 6.3%, 3,628.19 in fares (`GROUPING(origin_country) = 1`). |

**Who needs subtotals rather than detail rows.** The regional director. They are responsible for a whole region, not for one flight, and they compare regions with each other. Thirteen flight rows would make them add things up by hand; five subtotal rows answer their question directly. Singapore (10.5%) and Japan (9.6%) are above the platform rate, while Vietnam (0%) and Thailand (4.2%) are below it.

**What decision the grand total supports.** The grand total is the single platform figure that replaces the dashboard's wrong 46%. It is the number leadership uses to decide whether no-shows are a platform-wide problem that needs a platform-wide policy (for example, a change to overbooking or to the no-show fee), and it is the benchmark every region is measured against. The region rows on their own cannot answer either question, because a region being "high" only means something relative to the whole.

### Part C: A two-step pipeline

**The question the pipeline answers.** *What is a normal no-show rate for a busy flight on this platform, and which busy flights are clearly above it?*

Step 1 (`per_flight`, the `WITH` clause) builds one row per flight with its bookings, no-shows and rate denominator. Step 2 (`baseline`) filters that intermediate result to flights with at least 15 bookings and aggregates it again: a pooled rate, the median flight rate, and the minimum and maximum. The final `SELECT` puts each busy flight next to the baseline.

Result: eight high-volume flights covering 145 bookings, a pooled baseline of 5.0%, a median of 5.3%, and a range of 0% to 18.8%. VN202 is the only busy flight well above the baseline, at 13.8 points over it. The next highest, VN211, is only 1.7 points over, which is one no-show's worth.

---

## Task 4.3 Reflection: one pass versus two filtered queries

Conditional aggregation answers several questions in one trip through the data. In Part A, a single `GROUP BY` reads each booking once and asks it two things: does it count toward the total, and was it a no-show? `CASE` decides the bucket, and both totals land in the same row.

The alternative is two queries: one counting all bookings per flight, and a second with `WHERE cancellation_reason = 'Passenger no show'` counting only failures. That reads the table twice, and the two results then have to be joined back together on the flight. It also adds a correctness risk. A flight with no no-shows disappears from the filtered query, so after the join it shows NULL instead of zero unless someone remembers an outer join and `COALESCE`. If the data changes between the two queries, the numerator and denominator also come from different versions of the table.

At 200 rows none of this is noticeable. At a million rows it matters, because scanning the table is the expensive part. Two scans cost roughly twice as much as one, and every extra metric added the separate-query way adds another full scan and another join. With conditional aggregation, a third or fourth metric is just another `SUM(CASE ...)` column in the same pass, so the cost barely moves. For a dashboard that refreshes often, that keeps the query fast as the platform grows.
