-- ============================================================
-- Task 3.3: Hand the team a corrected query
-- Two-step question: which passengers were involved in the disputed bookings?
-- Step 1: find the disputed bookings.
-- Step 2: return those passengers.
-- Expected: 7 passengers (10 disputed bookings; passenger 5 has 3, passenger 16 has 2).
-- ============================================================

-- 3.3a Form 1: subquery with IN.
SELECT p.passenger_id, p.passenger_name, p.home_country
FROM passengers p
WHERE p.passenger_id IN (
    SELECT b.passenger_id
    FROM bookings b
    WHERE b.booking_status = 'disputed'
)
ORDER BY p.passenger_id;

-- 3.3b Form 2: Common Table Expression with WITH.
WITH disputed_passengers AS (
    SELECT DISTINCT passenger_id
    FROM bookings
    WHERE booking_status = 'disputed'
)
SELECT p.passenger_id, p.passenger_name, p.home_country
FROM passengers p
JOIN disputed_passengers d ON d.passenger_id = p.passenger_id
ORDER BY p.passenger_id;

-- 3.3c Form 3: correlated subquery with EXISTS.
SELECT p.passenger_id, p.passenger_name, p.home_country
FROM passengers p
WHERE EXISTS (
    SELECT 1
    FROM bookings b
    WHERE b.passenger_id = p.passenger_id
      AND b.booking_status = 'disputed'
)
ORDER BY p.passenger_id;

-- 3.3d Proof the three forms return identical rows, not just equal counts.
-- Each pair is compared with EXCEPT in both directions. If the result sets
-- are identical, every difference count is 0.
WITH f1 AS (
    SELECT p.passenger_id, p.passenger_name, p.home_country
    FROM passengers p
    WHERE p.passenger_id IN (SELECT passenger_id FROM bookings
                             WHERE booking_status = 'disputed')
),
f2 AS (
    SELECT p.passenger_id, p.passenger_name, p.home_country
    FROM passengers p
    JOIN (SELECT DISTINCT passenger_id FROM bookings
          WHERE booking_status = 'disputed') d
      ON d.passenger_id = p.passenger_id
),
f3 AS (
    SELECT p.passenger_id, p.passenger_name, p.home_country
    FROM passengers p
    WHERE EXISTS (SELECT 1 FROM bookings b
                  WHERE b.passenger_id = p.passenger_id
                    AND b.booking_status = 'disputed')
)
SELECT (SELECT COUNT(*) FROM f1) AS form1_rows,
       (SELECT COUNT(*) FROM f2) AS form2_rows,
       (SELECT COUNT(*) FROM f3) AS form3_rows,
       (SELECT COUNT(*) FROM (SELECT * FROM f1 EXCEPT SELECT * FROM f2) x) AS in_1_not_2,
       (SELECT COUNT(*) FROM (SELECT * FROM f2 EXCEPT SELECT * FROM f1) x) AS in_2_not_1,
       (SELECT COUNT(*) FROM (SELECT * FROM f1 EXCEPT SELECT * FROM f3) x) AS in_1_not_3,
       (SELECT COUNT(*) FROM (SELECT * FROM f3 EXCEPT SELECT * FROM f1) x) AS in_3_not_1;
-- Returns 7, 7, 7, 0, 0, 0, 0: the three result sets are identical row for row.

-- 3.3e Where equivalence breaks: duplicates.
-- If the CTE drops DISTINCT, the JOIN returns one row per disputed booking
-- instead of one per passenger. IN and EXISTS do not duplicate rows.
WITH disputed_bookings AS (
    SELECT passenger_id
    FROM bookings
    WHERE booking_status = 'disputed'
)
SELECT COUNT(*) AS join_rows_without_distinct
FROM passengers p
JOIN disputed_bookings d ON d.passenger_id = p.passenger_id;
-- Returns 10, not 7: passenger 5 appears 3 times and passenger 16 twice.
-- A second break: the negated forms. If the subquery could return a NULL,
-- NOT IN would return no rows at all, while NOT EXISTS would still work.
