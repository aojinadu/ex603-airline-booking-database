-- ============================================================
-- Task 5.2: Find records that joins may exclude
-- Theme: Airline Booking (producer = flights, event = bookings)
-- Run against: ex603_data loaded from airline.sql
-- Unit 4 showed 13 of the 15 flights have bookings (VN214 and VN215 have
-- none). These queries confirm that from the join side.
-- ============================================================

-- ------------------------------------------------------------
-- Part A: INNER JOIN vs LEFT JOIN
-- ------------------------------------------------------------

-- 5.2A-1 LEFT JOIN
-- Requirement: return every producer, including those with no events.
-- Question: For every flight, how many bookings does it have (zero
-- included)?
SELECT f.flight_id,
       f.flight_number,
       f.is_active,
       COUNT(b.booking_id) AS bookings
FROM flights f
LEFT JOIN bookings b ON b.flight_id = f.flight_id
GROUP BY f.flight_id, f.flight_number, f.is_active
ORDER BY bookings, f.flight_id;
-- Result: (fill in) 15 rows expected; flights with 0 bookings sort first.

-- 5.2A-2 INNER JOIN equivalent
-- Requirement: the same query written with INNER JOIN.
-- Question: Which flights appear when only flights with a matching
-- booking are kept?
SELECT f.flight_id,
       f.flight_number,
       f.is_active,
       COUNT(b.booking_id) AS bookings
FROM flights f
JOIN bookings b ON b.flight_id = f.flight_id
GROUP BY f.flight_id, f.flight_number, f.is_active
ORDER BY bookings, f.flight_id;
-- Result: (fill in) 13 rows expected.

-- 5.2A-3 How many producers does the INNER JOIN exclude?
-- Requirement: count excluded producers using unique identifiers
-- (COUNT DISTINCT), so a flight with many bookings is counted once.
-- Question: How many distinct flights does each join return, and what is
-- the difference?
SELECT (SELECT COUNT(DISTINCT f.flight_id)
        FROM flights f
        LEFT JOIN bookings b ON b.flight_id = f.flight_id) AS left_join_flights,
       (SELECT COUNT(DISTINCT f.flight_id)
        FROM flights f
        JOIN bookings b ON b.flight_id = f.flight_id)      AS inner_join_flights,
       (SELECT COUNT(DISTINCT f.flight_id)
        FROM flights f
        LEFT JOIN bookings b ON b.flight_id = f.flight_id)
     - (SELECT COUNT(DISTINCT f.flight_id)
        FROM flights f
        JOIN bookings b ON b.flight_id = f.flight_id)      AS excluded_by_inner_join;
-- Result: (fill in) expected 15, 13, 2.

-- 5.2A-4 Which producers are excluded?
-- Question: Which flights does the LEFT JOIN keep that the INNER JOIN
-- drops? (A LEFT JOIN row with a NULL booking side has no match.)
SELECT f.flight_id,
       f.flight_number,
       f.origin_country,
       f.first_scheduled_on,
       f.seat_capacity,
       f.is_active
FROM flights f
LEFT JOIN bookings b ON b.flight_id = f.flight_id
WHERE b.booking_id IS NULL
ORDER BY f.flight_id;
-- Result: (fill in) expected VN214 and VN215.

-- ------------------------------------------------------------
-- Part B: RIGHT JOIN and FULL OUTER JOIN
-- ------------------------------------------------------------

-- 5.2B-1 RIGHT JOIN that matches the LEFT JOIN from 5.2A-1
-- Requirement: same records as the LEFT JOIN, written as a RIGHT JOIN.
-- Question: Same as 5.2A-1. The tables are swapped so flights is now on
-- the right, which is the side a RIGHT JOIN keeps in full.
SELECT f.flight_id,
       f.flight_number,
       f.is_active,
       COUNT(b.booking_id) AS bookings
FROM bookings b
RIGHT JOIN flights f ON f.flight_id = b.flight_id
GROUP BY f.flight_id, f.flight_number, f.is_active
ORDER BY bookings, f.flight_id;
-- Result: (fill in) should be the same 15 rows as 5.2A-1.

-- 5.2B-2 Verify the LEFT and RIGHT JOIN results are identical
-- Requirement: verify rather than assume.
-- Question: Is there any row in one result that is not in the other?
-- Both EXCEPT directions returning 0 rows means the sets match.
WITH left_side AS (
    SELECT f.flight_id, COUNT(b.booking_id) AS bookings
    FROM flights f
    LEFT JOIN bookings b ON b.flight_id = f.flight_id
    GROUP BY f.flight_id
),
right_side AS (
    SELECT f.flight_id, COUNT(b.booking_id) AS bookings
    FROM bookings b
    RIGHT JOIN flights f ON f.flight_id = b.flight_id
    GROUP BY f.flight_id
)
SELECT 'in LEFT only'  AS direction, COUNT(*) AS rows_found
FROM (SELECT * FROM left_side EXCEPT SELECT * FROM right_side) x
UNION ALL
SELECT 'in RIGHT only', COUNT(*)
FROM (SELECT * FROM right_side EXCEPT SELECT * FROM left_side) y
UNION ALL
SELECT 'LEFT row count', COUNT(*) FROM left_side
UNION ALL
SELECT 'RIGHT row count', COUNT(*) FROM right_side;
-- Result: (fill in) expected 0, 0, 15, 15.

-- 5.2B-3 FULL OUTER JOIN
-- Requirement: matching and unmatched records from both tables.
-- Question: Are there flights with no bookings AND bookings with no
-- flight? Each row is labelled by which side it matched on.
SELECT CASE WHEN b.booking_id IS NULL THEN 'flight with no bookings'
            WHEN f.flight_id  IS NULL THEN 'booking with no flight'
            ELSE 'matched' END       AS match_type,
       COUNT(*)                      AS rows,
       COUNT(DISTINCT f.flight_id)   AS distinct_flights,
       COUNT(DISTINCT b.booking_id)  AS distinct_bookings
FROM flights f
FULL OUTER JOIN bookings b ON b.flight_id = f.flight_id
GROUP BY 1
ORDER BY 1;
-- Result: (fill in). The foreign key on bookings.flight_id means a
-- booking can only lack a flight if flight_id is NULL; expect 0 such rows.

-- 5.2B-4 FULL OUTER JOIN detail: only the unmatched rows from either side
SELECT f.flight_id, f.flight_number, b.booking_id, b.flight_id AS booking_flight_id
FROM flights f
FULL OUTER JOIN bookings b ON b.flight_id = f.flight_id
WHERE f.flight_id IS NULL OR b.booking_id IS NULL
ORDER BY f.flight_id, b.booking_id;
-- Result: (fill in).

-- ------------------------------------------------------------
-- Part C: Producers with no events, two ways
-- ------------------------------------------------------------

-- 5.2C-1 NOT EXISTS
-- Question: Which flights have no booking at all?
SELECT f.flight_id, f.flight_number
FROM flights f
WHERE NOT EXISTS (
    SELECT 1
    FROM bookings b
    WHERE b.flight_id = f.flight_id
)
ORDER BY f.flight_id;
-- Result: (fill in).

-- 5.2C-2 EXCEPT
-- Question: Same question, as a set difference: all flight ids minus the
-- flight ids that appear in bookings.
SELECT f.flight_id, f.flight_number
FROM flights f
WHERE f.flight_id IN (
    SELECT flight_id FROM flights
    EXCEPT
    SELECT flight_id FROM bookings
)
ORDER BY f.flight_id;
-- Result: (fill in).

-- 5.2C-3 Plain EXCEPT, ids only (the set operation on its own)
SELECT flight_id FROM flights
EXCEPT
SELECT flight_id FROM bookings
ORDER BY flight_id;
-- Result: (fill in) same ids as 5.2C-1.
