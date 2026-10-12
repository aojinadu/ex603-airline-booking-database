-- ============================================================
-- Task 3.2: Find the bug
-- ============================================================

-- ------------------------------------------------------------
-- Part A: The rows that vanished
-- Nullable column used: bookings.cancellation_reason
-- (nullable by design; no NULLs had to be inserted).
-- ------------------------------------------------------------

-- 3.2A-1 The broken filter. Intent: "every booking except the ones the
-- passenger cancelled themselves". Requirement: inequality on a nullable column.
SELECT COUNT(*) AS rows_kept_by_broken_filter
FROM bookings
WHERE cancellation_reason <> 'Passenger cancelled';
-- Returns 26.

-- 3.2A-2 The dashboard's rate, reproduced with the broken filter.
SELECT COUNT(*) FILTER (WHERE cancellation_reason = 'Passenger no show') AS no_shows,
       COUNT(*) AS bookings_in_denominator,
       ROUND(100.0 * COUNT(*) FILTER (WHERE cancellation_reason = 'Passenger no show')
             / COUNT(*), 1) AS no_show_rate_pct
FROM bookings
WHERE cancellation_reason <> 'Passenger cancelled';
-- Returns 12 / 26 = 46.2%: the "about half" the dashboard reported.

-- 3.2A-3 Count the rows the broken filter silently dropped, beside the
-- rows it was meant to drop and the table total.
SELECT (SELECT COUNT(*) FROM bookings
         WHERE cancellation_reason <> 'Passenger cancelled') AS kept_by_filter,
       (SELECT COUNT(*) FROM bookings
         WHERE cancellation_reason = 'Passenger cancelled')  AS intentionally_excluded,
       (SELECT COUNT(*) FROM bookings
         WHERE cancellation_reason IS NULL)                  AS silently_dropped_nulls,
       (SELECT COUNT(*) FROM bookings)                       AS table_total;
-- Returns 26, 8, 166, 200. 26 + 8 = 34, not 200.
-- The 166 missing rows are every confirmed and disputed booking: for them
-- NULL <> 'Passenger cancelled' is UNKNOWN, and WHERE keeps only TRUE.

-- 3.2A-4 The repair: handle NULL explicitly.
SELECT COUNT(*) AS rows_kept_by_repaired_filter
FROM bookings
WHERE cancellation_reason <> 'Passenger cancelled'
   OR cancellation_reason IS NULL;
-- Returns 192 (= 200 - 8), which is what was intended.

-- 3.2A-5 The repaired rate. (COALESCE gives the same result.)
SELECT COUNT(*) FILTER (WHERE cancellation_reason = 'Passenger no show') AS no_shows,
       COUNT(*) AS bookings_in_denominator,
       ROUND(100.0 * COUNT(*) FILTER (WHERE cancellation_reason = 'Passenger no show')
             / COUNT(*), 1) AS no_show_rate_pct
FROM bookings
WHERE COALESCE(cancellation_reason, 'No reason provided') <> 'Passenger cancelled';
-- Returns 12 / 192 = 6.3%.

-- ------------------------------------------------------------
-- Part B: The alias that did not exist yet
-- ------------------------------------------------------------

-- 3.2B-1 Broken: the alias base_fare is defined in SELECT but used in WHERE.
-- WHERE is evaluated before SELECT, so the alias does not exist yet.
-- This statement is left commented out so the file runs end to end.
-- Run it on its own to see the error.
-- SELECT booking_id,
--        fare_paid / fare_multiplier AS base_fare
-- FROM bookings
-- WHERE base_fare > 20;
--
-- Error message, verbatim:
-- ERROR:  column "base_fare" does not exist
-- LINE 4: WHERE base_fare > 20;
--               ^

-- 3.2B-2 Rewrite 1: repeat the expression in WHERE.
SELECT booking_id,
       ROUND(fare_paid / fare_multiplier, 2) AS base_fare
FROM bookings
WHERE fare_paid / fare_multiplier > 20
ORDER BY booking_id;

-- 3.2B-3 Rewrite 2: compute the alias in a CTE so it becomes a real column.
WITH priced AS (
    SELECT booking_id,
           fare_paid / fare_multiplier AS base_fare
    FROM bookings
)
SELECT booking_id,
       ROUND(base_fare, 2) AS base_fare
FROM priced
WHERE base_fare > 20
ORDER BY booking_id;
-- Both rewrites return the same 69 rows.
