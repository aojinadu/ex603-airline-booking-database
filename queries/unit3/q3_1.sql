-- ============================================================
-- Task 3.1: Establish what the data contains
-- Theme: Airline Booking (producer = flights, event = bookings)
-- Run against: ex603_data loaded from airline.sql
-- ============================================================

-- 3.1a Active, large-capacity flights: the producers whose bookings
-- anchor the audit. Requirement: SELECT, WHERE, ORDER BY, LIMIT.
-- Filter condition from the appendix: is_active = 1 AND seat_capacity >= 180
SELECT flight_id, flight_number, origin_country, seat_capacity
FROM flights
WHERE is_active = TRUE
  AND seat_capacity >= 180
ORDER BY seat_capacity DESC, flight_number
LIMIT 10;
-- Finding: 8 flights qualify, so LIMIT 10 returns all of them.
-- VN203 and VN209 are large but inactive, so they are correctly excluded.

-- 3.1b Every booking status that actually appears in the data.
-- Requirement: SELECT DISTINCT.
SELECT DISTINCT booking_status
FROM bookings
ORDER BY booking_status;
-- Finding: three statuses, not two: cancelled, confirmed, disputed.
-- There is no "no-show" status. A no-show is a cancelled booking whose
-- cancellation_reason is 'Passenger no show'.

-- 3.1b (follow-up) How many bookings sit in each status and reason.
SELECT booking_status,
       cancellation_reason,
       COUNT(*) AS bookings
FROM bookings
GROUP BY booking_status, cancellation_reason
ORDER BY booking_status, cancellation_reason;
-- Finding: 156 confirmed, 34 cancelled, 10 disputed (200 total).
-- Only 12 bookings are passenger no-shows.

-- 3.1c Bookings with a mid-range fare.
-- Requirement: WHERE with a numeric range (BETWEEN).
SELECT booking_id, flight_id, fare_paid, booking_status
FROM bookings
WHERE fare_paid BETWEEN 20.00 AND 30.00
ORDER BY fare_paid DESC;

-- 3.1c Bookings that did not end as a normal confirmed trip.
-- Requirement: WHERE with an explicit list of values (IN).
SELECT booking_id, flight_id, booking_status, cancellation_reason
FROM bookings
WHERE booking_status IN ('cancelled', 'disputed')
ORDER BY booking_status, booking_id;

-- 3.1d Flights whose flight number matches a text pattern.
-- Requirement: LIKE.
SELECT flight_id, flight_number, seat_capacity
FROM flights
WHERE flight_number LIKE 'VN21%'
ORDER BY flight_number;

-- 3.1d Bookings with no recorded cancellation reason, with the missing
-- value replaced by a readable label.
-- Requirement: IS NULL and COALESCE.
SELECT booking_id,
       booking_status,
       COALESCE(cancellation_reason, 'No reason provided') AS cancellation_reason
FROM bookings
WHERE cancellation_reason IS NULL
ORDER BY booking_id;
-- Finding: 166 bookings have no reason. These are every confirmed and
-- every disputed booking, which is expected: only cancellations have a reason.

-- 3.1e A readable booking report for someone who does not write SQL.
-- Requirement: computed columns and CASE.
SELECT b.booking_id,
       f.flight_number,
       b.fare_paid,
       ROUND(b.fare_paid / b.fare_multiplier, 2) AS base_fare_before_surge,
       CASE
           WHEN EXTRACT(HOUR FROM b.booked_at) BETWEEN 5 AND 11  THEN 'Morning'
           WHEN EXTRACT(HOUR FROM b.booked_at) BETWEEN 12 AND 16 THEN 'Afternoon'
           WHEN EXTRACT(HOUR FROM b.booked_at) BETWEEN 17 AND 21 THEN 'Evening'
           ELSE 'Overnight'
       END AS time_booked,
       CASE
           WHEN b.fare_paid = 0    THEN 'No fare collected'
           WHEN b.fare_paid < 15   THEN 'Low fare'
           WHEN b.fare_paid < 30   THEN 'Standard fare'
           ELSE 'Premium fare'
       END AS fare_band,
       CASE
           WHEN b.booking_status = 'confirmed' THEN 'Flew as booked'
           WHEN b.booking_status = 'disputed'  THEN 'Under dispute'
           WHEN b.cancellation_reason = 'Passenger no show' THEN 'Passenger did not show up'
           ELSE 'Cancelled: ' || b.cancellation_reason
       END AS outcome
FROM bookings b
JOIN flights f ON f.flight_id = b.flight_id
ORDER BY b.booking_id
LIMIT 20;
