-- ============================================================
-- Task 4.1: Measure the platform
-- Theme: Airline Booking (actor = passengers, producer = flights,
--        event = bookings, metric = fare_paid)
-- Run against: ex603_data loaded from airline.sql
--
-- Failure state (carried over from Unit 3): a passenger no-show,
-- i.e. cancellation_reason = 'Passenger no show'. The rate excludes
-- bookings the passenger cancelled themselves, and treats a NULL
-- cancellation_reason as "not a passenger cancellation" (the Unit 3 fix).
-- ============================================================

-- 4.1a Platform baseline for the metric.
-- Requirement: COUNT, SUM, AVG, MIN, MAX and COUNT(DISTINCT) over the whole
-- event table.
-- Question: How many bookings are there, how much fare was collected, what
-- is a typical fare, what are the lowest and highest fares, and how many
-- different passengers booked?
SELECT COUNT(*)                     AS bookings,
       SUM(b.fare_paid)             AS total_fare,
       ROUND(AVG(b.fare_paid), 2)   AS avg_fare,
       MIN(b.fare_paid)             AS min_fare,
       MAX(b.fare_paid)             AS max_fare,
       COUNT(DISTINCT b.passenger_id) AS distinct_passengers
FROM bookings b;
-- Result: 200 bookings, 3628.19 total, 18.14 average, min 0.00,
-- max 70.86, 30 distinct passengers.

-- 4.1a (follow-up) Where do the zero fares come from?
-- Requirement: investigate the suspicious MIN of 0.00.
-- Question: Which booking outcomes carry a fare of zero, and what does the
-- average fare look like once they are set aside?
SELECT b.booking_status,
       COUNT(*)                                        AS bookings,
       COUNT(*) FILTER (WHERE b.fare_paid = 0)         AS zero_fare_bookings,
       ROUND(AVG(b.fare_paid), 2)                      AS avg_fare
FROM bookings b
GROUP BY b.booking_status
ORDER BY b.booking_status;
-- Result: all 34 cancelled bookings have fare_paid = 0; no confirmed or
-- disputed booking does. The 18.14 platform average is pulled down by
-- those zeros: confirmed bookings average 21.92 and disputed 20.94.

-- 4.1b Event count and average metric per producer.
-- Requirement: GROUP BY with aggregates, sorted by volume.
-- Question: Which flights carry the most bookings, and what does a booking
-- on each flight typically pay?
SELECT f.flight_id,
       f.flight_number,
       COUNT(*)                   AS bookings,
       ROUND(AVG(b.fare_paid), 2) AS avg_fare
FROM bookings b
JOIN flights f ON f.flight_id = b.flight_id
GROUP BY f.flight_id, f.flight_number
ORDER BY bookings DESC, f.flight_id;
-- Result: 13 of the 15 flights have bookings (VN214 and VN215 have none).
-- Volume runs from 21 (VN206) down to 6 (VN204). Average fare runs from
-- 23.06 (VN205) down to 11.94 (VN211).

-- 4.1c Producers with enough volume for their rate to mean anything.
-- Requirement: HAVING on a grouped count.
-- Question: Among flights with at least 15 bookings, what is each flight's
-- no-show rate?
-- Threshold: 15. At the platform rate of about 6%, a flight needs roughly
-- 15 bookings before even one no-show is expected, and below that a single
-- no-show moves the rate by 7 or more percentage points. 15 is also close
-- to the platform average of 200 / 13 = 15.4 bookings per flight.
SELECT f.flight_id,
       f.flight_number,
       COUNT(*) AS bookings,
       COUNT(*) FILTER (WHERE b.cancellation_reason = 'Passenger no show') AS no_shows,
       ROUND(100.0 * COUNT(*) FILTER (WHERE b.cancellation_reason = 'Passenger no show')
             / NULLIF(COUNT(*) FILTER (WHERE COALESCE(b.cancellation_reason, 'none')
                                            <> 'Passenger cancelled'), 0), 1) AS no_show_rate_pct
FROM bookings b
JOIN flights f ON f.flight_id = b.flight_id
GROUP BY f.flight_id, f.flight_number
HAVING COUNT(*) >= 15
ORDER BY bookings DESC, f.flight_id;
-- Result: 8 flights qualify. VN202 stands out at 18.8% (3 of 16);
-- the other seven are between 0% and 6.3%.

-- 4.1d Two dimensions at once: region and booking outcome.
-- Requirement: GROUP BY two columns, one of them region.
-- Region = flights.origin_country, the country the flight is based in.
-- Question: For each region, how many bookings ended in each outcome, how
-- much fare did they bring in, and what was the average fare?
SELECT f.origin_country               AS region,
       b.booking_status,
       COUNT(*)                       AS bookings,
       COUNT(DISTINCT f.flight_id)    AS flights,
       SUM(b.fare_paid)               AS total_fare,
       ROUND(AVG(b.fare_paid), 2)     AS avg_fare
FROM bookings b
JOIN flights f ON f.flight_id = b.flight_id
GROUP BY f.origin_country, b.booking_status
ORDER BY region, b.booking_status;
-- Result: one row per region and outcome that occurs: 12 rows across 5
-- regions. Vietnam has no cancelled or disputed bookings at all. Korea
-- carries 6 of the 10 disputes, and Japan the most cancellations (13).
