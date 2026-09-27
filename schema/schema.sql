-- =================================================================
-- EX 603 Assignment 2 — schema.sql
-- Theme: <your theme>
-- Author: <your name>
-- Target: PostgreSQL 14+
-- =================================================================
-- Reset. Reverse creation order, so no dependency blocks a drop.

DROP TABLE IF EXISTS flights    CASCADE;
DROP TABLE IF EXISTS bookings   CASCADE;
DROP TABLE IF EXISTS airports   CASCADE;
DROP TABLE IF EXISTS flight_routes    CASCADE;
DROP TABLE IF EXISTS passengers    CASCADE;


-- -----------------------------------------------------------------
-- Position 1 of 5 in the creation order.
-- First because it carries no foreign keys of its own, so nothing has
-- to exist before it -- and bookings cannot be created until it does.
-- -----------------------------------------------------------------
CREATE TABLE passengers (
    passenger_id   INTEGER      GENERATED ALWAYS AS IDENTITY,
    firstname      VARCHAR(120) NOT NULL,
    lastname          VARCHAR(255) NOT NULL,

    CONSTRAINT pk_passengers       PRIMARY KEY (passenger_id),
    CONSTRAINT ck_passengers_firstname  CHECK (length(trim(firstname)) > 0),
    CONSTRAINT ck_passengers_lastname  CHECK (length(trim(lastname)) > 0)
);


-- -----------------------------------------------------------------
-- Position 2 of 5 in the creation order.
-- Also self-contained (no outgoing foreign keys), but it sits ahead of
-- bookings and flight_routes because both of them reference it.
-- -----------------------------------------------------------------
CREATE TABLE flights (
    flight_id            INTEGER       GENERATED ALWAYS AS IDENTITY,
    flight_number        VARCHAR(8)    NOT NULL,
    flight_name        VARCHAR(255)    NOT NULL,
    flight_description        VARCHAR(2000)    NOT NULL,
    CONSTRAINT pk_flights           PRIMARY KEY (flight_id),
    CONSTRAINT uq_flights_departure UNIQUE (flight_number),
    CONSTRAINT chk_flights_number    CHECK (flight_number ~ '^[A-Z0-9]{2}[0-9]{1,4}$')
);

-- -----------------------------------------------------------------
-- Position 3 of 5 in the creation order.
-- Self-contained as well, so its slot is flexible; it is placed here
-- simply to precede flight_routes, the only table that references it.
-- -----------------------------------------------------------------
CREATE TABLE airports (
    airport_id    INTEGER      GENERATED ALWAYS AS IDENTITY,
    name  VARCHAR(120) NOT NULL,
    country          VARCHAR(80)  NOT NULL,
    code  VARCHAR(3)   NOT NULL,

    CONSTRAINT pk_airports         PRIMARY KEY (airport_id),
    CONSTRAINT chk_airports_country CHECK (code ~ '^[A-Z]{3}$')
);

-- -----------------------------------------------------------------
-- Position 4 of 5 in the creation order.
-- The first table with outgoing foreign keys -- to passengers (1) and
-- flights (2) -- so it can only be created once both already exist.
-- -----------------------------------------------------------------
CREATE TABLE bookings (
    booking_id      INTEGER       GENERATED ALWAYS AS IDENTITY,
    flight_route_id INTEGER       NOT NULL,
    passenger_id    INTEGER       NOT NULL,
    flight_id       INTEGER       NOT NULL,
    departure_date  TIMESTAMP     NOT NULL DEFAULT now(),
    arrival_date    TIMESTAMP     NOT NULL DEFAULT now(),
    fare_paid       NUMERIC(10,2) NOT NULL,
    flight_number     VARCHAR(8),

    CONSTRAINT pk_bookings PRIMARY KEY (booking_id),

    CONSTRAINT fk_bookings_passenger FOREIGN KEY (passenger_id)
        REFERENCES passengers (passenger_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,

    CONSTRAINT fk_bookings_flight FOREIGN KEY (flight_id)
        REFERENCES flights (flight_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,

    CONSTRAINT chk_bookings_fare   CHECK (fare_paid >= 0),
    CONSTRAINT chk_bookings_flight_number   CHECK (flight_number IS NOT NULL)
);

CREATE INDEX ix_bookings_passenger ON bookings (passenger_id, departure_date DESC);
CREATE INDEX ix_bookings_flight    ON bookings (flight_id);


-- -----------------------------------------------------------------
-- Position 5 of 5 in the creation order.
-- Last because it is the most dependent table, pointing at flights (2)
-- and twice at airports (3); every table it needs is already in place.
-- -----------------------------------------------------------------
CREATE TABLE flight_routes (
    flight_route_id         INTEGER     NOT NULL,
    destination_airport_id  INTEGER     NOT NULL,
    arrival_airport_id      INTEGER     NOT NULL,
    departure_date          TIMESTAMP     NOT NULL DEFAULT now(),
    arrival_date            TIMESTAMP     NOT NULL DEFAULT now(),

    CONSTRAINT pk_flight_routes PRIMARY KEY (flight_route_id),

    CONSTRAINT fk_routes_flight FOREIGN KEY (flight_route_id)
        REFERENCES flights (flight_id)
        ON UPDATE CASCADE
        ON DELETE CASCADE,

    CONSTRAINT fk_routes_departure_airport FOREIGN KEY (destination_airport_id)
        REFERENCES airports (airport_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,

    CONSTRAINT fk_routes_arrival_airport FOREIGN KEY (arrival_airport_id)
        REFERENCES airports (airport_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT
);

CREATE UNIQUE INDEX uq_routes_one_origin
    ON flight_routes (flight_route_id);

CREATE INDEX ix_routes_arrival_airport ON flight_routes (arrival_airport_id);
CREATE INDEX ix_routes_destination_airport ON flight_routes (destination_airport_id);
