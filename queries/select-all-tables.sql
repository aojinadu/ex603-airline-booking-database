-- =================================================================
-- EX 603 Assignment 2 — select-all-tables.sql
-- Connection: horilla@localhost   Database: bu_bootstrap   Schema: public
-- Target: PostgreSQL 14+
--
-- SELECT * over the five tables created by schema/schema.sql,
-- in the same order they are created, so foreign keys read top-down.
-- =================================================================

-- Position 1 of 5 — the actor. No foreign keys out.
SELECT * FROM passengers;

-- Position 2 of 5 — the producer. Referenced by bookings and flight_routes.
SELECT * FROM flights;

-- Position 3 of 5 — the catalog. Referenced twice by flight_routes.
SELECT * FROM airports;

-- Position 4 of 5 — the event. Points at passengers (1) and flights (2).
SELECT * FROM bookings;

-- Position 5 of 5 — the junction. Points at flights (2) and airports (3).
SELECT * FROM flight_routes;
