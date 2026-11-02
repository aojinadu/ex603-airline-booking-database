-- ============================================================
-- Task 4.2: Build the breakdown leadership asked for
-- Theme: Airline Booking (producer = flights, event = bookings)
-- Run against: ex603_data loaded from airline.sql
--
-- Failure state: cancellation_reason = 'Passenger no show'.
-- Rate denominator: every booking except the ones the passenger cancelled
-- themselves, with NULL reasons kept (COALESCE), as fixed in Unit 3.
-- ============================================================

-- ------------------------------------------------------------
-- Part A: Two numbers in one pass
-- Requirement: CASE inside an aggregate; both totals as separate columns;
-- no WHERE clause filtering the whole query.
-- Questions answered side by side, per flight:
--   1. How many bookings did this flight take in total?
--   2. How many of those bookings ended in a passenger no-show?
-- The rate column is derived from the same single pass.
-- ------------------------------------------------------------
SELECT f.flight_id,
       f.flight_number,
       COUNT(*) AS total_bookings,
       SUM(CASE WHEN b.cancellation_reason = 'Passenger no show'
                THEN 1 ELSE 0 END) AS no_show_bookings,
       SUM(CASE WHEN COALESCE(b.cancellation_reason, 'none') <> 'Passenger cancelled'
                THEN 1 ELSE 0 END) AS bookings_in_rate,
       ROUND(100.0 * SUM(CASE WHEN b.cancellation_reason = 'Passenger no show'
                              THEN 1 ELSE 0 END)
             / NULLIF(SUM(CASE WHEN COALESCE(b.cancellation_reason, 'none') <> 'Passenger cancelled'
                               THEN 1 ELSE 0 END), 0), 1) AS no_show_rate_pct
FROM bookings b
JOIN flights f ON f.flight_id = b.flight_id
GROUP BY f.flight_id, f.flight_number
ORDER BY no_show_rate_pct DESC, total_bookings DESC;
-- Result: 13 flights, 200 bookings, 12 no-shows. Outliers:
--   VN202  16 bookings, 3 no-shows, 18.8%  (three times the platform rate)
--   VN203  13 bookings, 2 no-shows, 16.7%  (flight is marked inactive)
--   VN204   6 bookings, 1 no-show,  16.7%  (too few bookings to judge)
-- Four flights (VN208, VN210, VN205, VN213) have no no-shows at all.

-- ------------------------------------------------------------
-- Part B: Subtotals and a grand total
-- Requirement: GROUP BY ROLLUP, producing subtotals and a grand total
-- with no detail rows.
-- Question: For each region, and for the platform as a whole, how many
-- bookings, no-shows and what no-show rate?
-- Region = flights.origin_country.
-- How to read the output:
--   * row_type = 'Region subtotal' (GROUPING(f.origin_country) = 0):
--     one row per region, totalled over every flight based there.
--   * row_type = 'Platform grand total' (GROUPING(f.origin_country) = 1,
--     region shown as 'ALL REGIONS'): the single last row, all 200 bookings.
-- ROLLUP (f.origin_country) produces exactly two levels: one row per region
-- and one () row for the platform. The flight is deliberately left out of
-- the ROLLUP list, so the per-flight detail rows that
-- ROLLUP (origin_country, flight_number) would return are never produced.
-- The same result comes from GROUPING SETS ((f.origin_country), ()).
-- ------------------------------------------------------------
SELECT CASE WHEN GROUPING(f.origin_country) = 1 THEN 'Platform grand total'
            ELSE 'Region subtotal' END                     AS row_type,
       COALESCE(f.origin_country, 'ALL REGIONS')            AS region,
       COUNT(DISTINCT f.flight_id)                          AS flights,
       COUNT(*)                                             AS total_bookings,
       SUM(CASE WHEN b.cancellation_reason = 'Passenger no show'
                THEN 1 ELSE 0 END)                          AS no_show_bookings,
       ROUND(100.0 * SUM(CASE WHEN b.cancellation_reason = 'Passenger no show'
                              THEN 1 ELSE 0 END)
             / NULLIF(SUM(CASE WHEN COALESCE(b.cancellation_reason, 'none') <> 'Passenger cancelled'
                               THEN 1 ELSE 0 END), 0), 1)   AS no_show_rate_pct,
       SUM(b.fare_paid)                                     AS total_fare
FROM bookings b
JOIN flights f ON f.flight_id = b.flight_id
GROUP BY ROLLUP (f.origin_country)
ORDER BY GROUPING(f.origin_country), region;
-- Result: five region subtotal rows, then one grand total row:
-- ALL REGIONS, 13 flights, 200 bookings, 12 no-shows, 6.3%, 3628.19.

-- ------------------------------------------------------------
-- Part C: A two-step pipeline
-- Requirement: a WITH clause producing an intermediate aggregate, then a
-- second aggregation applied to that intermediate result.
-- Question: Across flights with at least 15 bookings, what is the typical
-- no-show rate (the baseline), how widely does it range, and which
-- flights sit above it?
-- Step 1 (per_flight): one row per flight with its volume and rate.
-- Step 2 (baseline): filter to high-volume flights and aggregate the
--   step-1 rows into a pooled rate, an average of flight rates, a median,
--   and the minimum and maximum.
-- Final SELECT: each high-volume flight beside the baseline.
-- ------------------------------------------------------------
WITH per_flight AS (
    SELECT f.flight_id,
           f.flight_number,
           COUNT(*) AS total_bookings,
           SUM(CASE WHEN b.cancellation_reason = 'Passenger no show'
                    THEN 1 ELSE 0 END) AS no_show_bookings,
           SUM(CASE WHEN COALESCE(b.cancellation_reason, 'none') <> 'Passenger cancelled'
                    THEN 1 ELSE 0 END) AS bookings_in_rate
    FROM bookings b
    JOIN flights f ON f.flight_id = b.flight_id
    GROUP BY f.flight_id, f.flight_number
),
baseline AS (
    SELECT COUNT(*)                                          AS high_volume_flights,
           SUM(total_bookings)                               AS bookings_covered,
           ROUND(100.0 * SUM(no_show_bookings)
                 / SUM(bookings_in_rate), 1)                 AS pooled_rate_pct,
           ROUND(AVG(100.0 * no_show_bookings
                     / bookings_in_rate), 1)                 AS avg_flight_rate_pct,
           ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP
                 (ORDER BY 100.0 * no_show_bookings / bookings_in_rate)::numeric, 1)
                                                             AS median_flight_rate_pct,
           ROUND(MIN(100.0 * no_show_bookings / bookings_in_rate), 1) AS min_rate_pct,
           ROUND(MAX(100.0 * no_show_bookings / bookings_in_rate), 1) AS max_rate_pct
    FROM per_flight
    WHERE total_bookings >= 15
)
SELECT p.flight_number,
       p.total_bookings,
       p.no_show_bookings,
       ROUND(100.0 * p.no_show_bookings / p.bookings_in_rate, 1)  AS flight_rate_pct,
       bl.pooled_rate_pct                                         AS baseline_pct,
       ROUND(100.0 * p.no_show_bookings / p.bookings_in_rate
             - bl.pooled_rate_pct, 1)                             AS points_vs_baseline,
       bl.median_flight_rate_pct,
       bl.min_rate_pct,
       bl.max_rate_pct,
       bl.high_volume_flights
FROM per_flight p
CROSS JOIN baseline bl
WHERE p.total_bookings >= 15
ORDER BY points_vs_baseline DESC, p.total_bookings DESC;
-- Result: 8 high-volume flights covering 145 bookings. Pooled baseline
-- 5.0%, median flight rate 5.3%, range 0.0% to 18.8%. VN202 is the only
-- high-volume flight well above the baseline (+13.8 points).
