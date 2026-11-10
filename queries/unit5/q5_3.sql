-- ============================================================
-- Task 5.3: Join performance and execution plans
-- Theme: Airline Booking
-- Run against: ex603_data loaded from airline.sql
-- ============================================================

-- ------------------------------------------------------------
-- Part A: CROSS JOIN
-- Tables: flights (producer, 15 rows per Unit 4) and airports (catalog).
-- Both are small, so the Cartesian product stays readable.
-- ------------------------------------------------------------

-- 5.3A-1 Source table counts, CROSS JOIN count, and the check, in one result
-- Requirement: count each source table, count the CROSS JOIN, and show
-- the result equals the product of the two counts.
-- Question: If every flight is paired with every airport, how many pairs
-- are there, and does that equal flights x airports?
SELECT (SELECT COUNT(*) FROM flights)                        AS flights_rows,
       (SELECT COUNT(*) FROM airports)                       AS airports_rows,
       (SELECT COUNT(*) FROM flights) * (SELECT COUNT(*) FROM airports)
                                                             AS expected_product,
       (SELECT COUNT(*) FROM flights CROSS JOIN airports)    AS cross_join_rows,
       (SELECT COUNT(*) FROM flights CROSS JOIN airports)
     = (SELECT COUNT(*) FROM flights) * (SELECT COUNT(*) FROM airports)
                                                             AS matches;
-- Result: (fill in) flights_rows x airports_rows = cross_join_rows, matches = true.

-- 5.3A-2 The CROSS JOIN rows themselves
-- Question: What does every flight-airport pairing look like? A useful
-- version: mark which pairings are real routes, so the grid doubles as a
-- coverage map (which airports each flight does NOT serve).
SELECT f.flight_number,
       a.iata_code,
       EXISTS (SELECT 1
               FROM flight_routes fr
               WHERE fr.flight_id = f.flight_id
                 AND fr.airport_id = a.airport_id) AS is_real_route
FROM flights f
CROSS JOIN airports a
ORDER BY f.flight_number, a.iata_code;
-- Result: (fill in) same row count as cross_join_rows above.

-- ------------------------------------------------------------
-- Part B: Execution plan for the three-table join from 5.1a
-- Requirement: EXPLAIN the 5.1a query, identify the join algorithms.
-- EXPLAIN ANALYZE runs the query and adds real row counts and timings.
-- Safe here: it is a read-only SELECT.
-- ------------------------------------------------------------

-- 5.3B-1 Estimated plan only
EXPLAIN
SELECT b.booking_id,
       p.passenger_id,
       p.passenger_name,
       f.flight_id,
       f.flight_number,
       b.booked_at,
       b.booking_status,
       b.cancellation_reason
FROM bookings b
JOIN passengers p ON p.passenger_id = b.passenger_id
JOIN flights    f ON f.flight_id    = b.flight_id
ORDER BY b.booked_at, b.booking_id;

-- 5.3B-2 Plan with actual execution
EXPLAIN (ANALYZE, BUFFERS)
SELECT b.booking_id,
       p.passenger_id,
       p.passenger_name,
       f.flight_id,
       f.flight_number,
       b.booked_at,
       b.booking_status,
       b.cancellation_reason
FROM bookings b
JOIN passengers p ON p.passenger_id = b.passenger_id
JOIN flights    f ON f.flight_id    = b.flight_id
ORDER BY b.booked_at, b.booking_id;
-- Result: (paste the plan here as comments after running).

-- 5.3B-3 Supporting evidence: which indexes exist on the joined tables
-- Question: Are the join columns indexed? This explains the planner's choice.
SELECT tablename, indexname, indexdef
FROM pg_indexes
WHERE tablename IN ('bookings', 'passengers', 'flights')
ORDER BY tablename, indexname;
