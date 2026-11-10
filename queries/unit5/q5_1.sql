-- ============================================================
-- Task 5.1: Connect producers to their data
-- Theme: Airline Booking (actor = passengers, producer = flights,
--        event = bookings, catalog = airports, junction = flight_routes)
-- Run against: ex603_data loaded from airline.sql
--
-- Flights flagged in Unit 4 (passenger no-show rate):
--   VN202  16 bookings, 3 no-shows, 18.8%  (only high-volume outlier)
--   VN203  13 bookings, 2 no-shows, 16.7%  (flight is marked inactive)
--   VN204   6 bookings, 1 no-show,  16.7%  (too few bookings to judge)
-- ============================================================

-- ------------------------------------------------------------
-- 5.1a Three-table join: actor + producer + event
-- Requirement: INNER JOIN across three tables showing the actor, the
-- producer and the event's date and time.
-- Question: For every booking, which passenger made it, which flight was
-- it on, and when was it booked?
-- ------------------------------------------------------------
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
-- Result: (fill in) rows, one per booking.

-- 5.1a (focused) The same join, narrowed to the flagged flights.
-- Question: Who were the passengers who did not show up on the flights
-- flagged in Unit 4, and when did they book?
SELECT f.flight_number,
       p.passenger_name,
       p.home_country,
       b.booked_at,
       b.checked_in_at,
       b.cancellation_reason
FROM bookings b
JOIN passengers p ON p.passenger_id = b.passenger_id
JOIN flights    f ON f.flight_id    = b.flight_id
WHERE f.flight_number IN ('VN202', 'VN203', 'VN204')
  AND b.cancellation_reason = 'Passenger no show'
ORDER BY f.flight_number, b.booked_at;
-- Result: (fill in) 6 no-shows expected (3 + 2 + 1).

-- ------------------------------------------------------------
-- 5.1b Junction traversal: producer -> junction -> catalog
-- Requirement: connect flights to airports through flight_routes and
-- return the producers associated with the theme's catalog tag.
-- Catalog tag for this theme = the airport (iata_code) a flight serves.
-- Question: Which airports does each flight serve, and do the flagged
-- flights share an airport with each other?
-- ------------------------------------------------------------
SELECT f.flight_number,
       f.is_active,
       a.iata_code,
       a.airport_name,
       fr.effective_from,
       CASE WHEN f.flight_number IN ('VN202', 'VN203', 'VN204')
            THEN 'flagged in Unit 4' ELSE '' END AS unit4_flag
FROM flights f
JOIN flight_routes fr ON fr.flight_id  = f.flight_id
JOIN airports      a  ON a.airport_id  = fr.airport_id
ORDER BY a.iata_code, f.flight_number;
-- Result: (fill in) rows. Note which airport codes the flagged flights use.

-- 5.1b (summary) Airports by how many flagged flights serve them.
-- Question: Is there an airport that the high-no-show flights have in
-- common, compared with all flights serving it?
SELECT a.iata_code,
       a.airport_name,
       COUNT(DISTINCT f.flight_id) AS flights_serving,
       COUNT(DISTINCT f.flight_id) FILTER (
           WHERE f.flight_number IN ('VN202', 'VN203', 'VN204')) AS flagged_flights_serving,
       STRING_AGG(DISTINCT f.flight_number, ', ') AS flight_numbers
FROM airports a
JOIN flight_routes fr ON fr.airport_id = a.airport_id
JOIN flights       f  ON f.flight_id   = fr.flight_id
GROUP BY a.airport_id, a.iata_code, a.airport_name
ORDER BY flagged_flights_serving DESC, flights_serving DESC, a.iata_code;
-- Result: (fill in).

-- ------------------------------------------------------------
-- 5.1c Self join on the producer table
-- Requirement: join flights to itself to compare producers.
-- Question: For each flagged flight, which other flights are based in the
-- same country, and how do they compare on seat capacity, start date,
-- active status and booking volume?
-- f1 = the flagged flight, f2 = a peer flight from the same origin country.
-- Booking volume comes from a per-flight count joined to each side.
-- ------------------------------------------------------------
WITH volume AS (
    SELECT flight_id,
           COUNT(*) AS bookings,
           COUNT(*) FILTER (WHERE cancellation_reason = 'Passenger no show') AS no_shows
    FROM bookings
    GROUP BY flight_id
)
SELECT f1.flight_number                 AS flagged_flight,
       f1.origin_country,
       f1.seat_capacity                 AS flagged_capacity,
       f1.first_scheduled_on            AS flagged_start,
       f1.is_active                     AS flagged_active,
       COALESCE(v1.bookings, 0)         AS flagged_bookings,
       COALESCE(v1.no_shows, 0)         AS flagged_no_shows,
       f2.flight_number                 AS peer_flight,
       f2.seat_capacity                 AS peer_capacity,
       f2.first_scheduled_on            AS peer_start,
       f2.is_active                     AS peer_active,
       COALESCE(v2.bookings, 0)         AS peer_bookings,
       COALESCE(v2.no_shows, 0)         AS peer_no_shows
FROM flights f1
JOIN flights f2
  ON f2.origin_country = f1.origin_country
 AND f2.flight_id     <> f1.flight_id
LEFT JOIN volume v1 ON v1.flight_id = f1.flight_id
LEFT JOIN volume v2 ON v2.flight_id = f2.flight_id
WHERE f1.flight_number IN ('VN202', 'VN203', 'VN204')
ORDER BY f1.flight_number, f2.flight_number;
-- Result: (fill in). Look for whether the flagged flights differ from
-- their same-country peers on capacity, age, active status or volume.
