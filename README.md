# EX 603 Assignment 2: Airline Booking Database

A relational schema for an airline seat-booking platform, written for **PostgreSQL 14+**.

Theme 5: Airline Booking. The database records who flies, which flights exist, where those
flights go, and what each passenger paid for a seat.

## Repository layout

| Path | Contents |
| --- | --- |
| `schema/schema.sql` | The schema. Drops and recreates all five tables plus their indexes. |
| `queries/select-all-tables.sql` | `SELECT *` over each table, in creation order. |
| `queries/airline-booking.sql` | Earlier working draft of the schema. Superseded by `schema/schema.sql`. |
| `analysis/unit2.md` | Task 2.2 write-up: every foreign key's `ON DELETE` choice and every `CHECK`, with reasoning. |
| `analysis/Airline Booking Flow Model.mmd` | ER diagram (Mermaid). |
| `analysis/schema-relation` | Plain-text relation and attribute list the schema was built from. |
| `analysis/Integrity constraints.docx` | Constraint documentation. |
| `analysis/Model justification.docx` | Justification of the data model. |
| `analysis/Schema Relation.docx` | Relation list, formatted. |
| `analysis/Reflection.docx` | Assignment reflection. |
| `screenshots/Airline Booking Flow Model.png` | Rendered ER diagram. |
| `screenshots/create-table1–3.png` | Table creation, captured from DataGrip. |
| `screenshots/resulting table.png` | Result grid after creation. |

## Running it

```bash
psql -d <your_database> -f schema/schema.sql
```

The script is idempotent: it opens with `DROP TABLE IF EXISTS ... CASCADE` for all five
tables, so it can be re-run over an existing copy without manual cleanup. **It destroys
existing data in those five tables**, which is intended for coursework but worth noting
before pointing it at anything else.

Verify afterwards with:

```bash
psql -d <your_database> -f queries/select-all-tables.sql
```

---

## Schema

Five tables. Each fills one role in the standard actor / producer / event / catalog / junction
shape, and each is created in dependency order so that no foreign key ever references a table
that does not yet exist.

| # | Table | Role | What it holds |
| --- | --- | --- | --- |
| 1 | `passengers` | actor | One row per person who can book. `firstname`, `lastname`. No outgoing foreign keys. |
| 2 | `flights` | producer | One row per flight service. `flight_number` (IATA designator, unique), `flight_name`, `flight_description`. |
| 3 | `airports` | catalog | One row per airport. `name`, `country`, and a 3-letter IATA `code`. |
| 4 | `bookings` | event | One row per seat sold. Links a passenger to a flight and records `fare_paid`, `departure_date`, `arrival_date`. |
| 5 | `flight_routes` | junction | Where a flight goes: a departure airport, an arrival airport, and the scheduled times. |

Relationships:

```
passengers (1) ──< bookings >── (1) flights
                                     │
                                     │ 1:1
                                     ▼
                              flight_routes ──> airports  (departure)
                                            ──> airports  (arrival)
```

### Design decisions a reader should notice

**1. `flight_routes` is one-to-one with `flights`, not a many-to-many junction.**
The table's primary key `flight_route_id` *is* its foreign key to `flights.flight_id`. That
single column serves both purposes, so a flight has exactly one route row: one departure
airport, one arrival airport. The consequence is that **this schema models direct flights
only**; it cannot represent a multi-stop itinerary. That is a deliberate narrowing. Note that
`analysis/Airline Booking Flow Model.mmd` shows `flight_routes` as a true composite-key
junction with a stop sequence, which would support stopovers; the implemented schema is the
simpler of the two designs, and the diagram is the one that is out of date.

**2. The delete policy is split by what the data represents, not by table.**
Four of the five foreign keys use `ON DELETE RESTRICT`; one uses `CASCADE`. The rule behind
the split is whether a child row records a third-party commitment or merely describes its
parent:

- `bookings` rows record money taken and a seat held, so they are protected. A flight or a
  passenger with bookings attached **cannot be deleted at all** until those bookings are
  resolved. Deleting a flight does not quietly delete the seats sold on it.
- `flight_routes` rows only state where a flight goes, and mean nothing without it, so they
  cascade. Because `bookings` is protected by `RESTRICT` and is checked on the same delete,
  this cascade can only ever fire for a flight that has no commercial history.

Full reasoning for each of the five, including what would break under the alternative, is in
`analysis/unit2.md`.

**3. Every primary key is `INTEGER GENERATED ALWAYS AS IDENTITY`.**
Not `SERIAL`, and not MySQL's `AUTO_INCREMENT`. `GENERATED ALWAYS` means the database owns
the value: an `INSERT` that supplies its own `flight_id` is rejected rather than silently
accepted, so application code cannot create rows that collide with the sequence later.

**4. Money is `NUMERIC(10,2)`, never a floating-point type.**
`fare_paid` is exact. `FLOAT` would accumulate rounding error across aggregation, so a
`SUM(fare_paid)` over a flight would drift from the true total.

**5. Domain formats are enforced in the database, not only in the application.**
`flight_number` must match `^[A-Z0-9]{2}[0-9]{1,4}$` and `airports.code` must match
`^[A-Z]{3}$`. These pair with the `UNIQUE` constraint on `flight_number` to do real work:
`VARCHAR` comparison is case-sensitive in PostgreSQL, so without the pattern `BA75` and
`ba75` would be two distinct values to the unique index and one flight could be stored twice.
The name checks on `passengers` use `length(trim(...)) > 0` rather than relying on `NOT NULL`,
because a blank web form submits an empty string, which `NOT NULL` accepts.

**6. `bookings` deliberately repeats data held elsewhere.**
`flight_number` duplicates a value reachable via `flight_id`, and `departure_date` /
`arrival_date` duplicate columns on `flight_routes`. Repeating the designator can be justified
as preserving it *as the seat was sold*, so a later renumbering does not rewrite history, but
nothing in the schema keeps the copies in sync, so they are free to drift. Read them as
snapshots, not as the current truth.

**7. `flights` carries no schedule.**
There are no timestamps on `flights` at all. Scheduled times live on `flight_routes` and are
copied onto each `bookings` row. A reader expecting `flights.scheduled_departure` will not
find it.

**8. Indexes go on the foreign-key columns that get filtered.**
`ix_bookings_passenger (passenger_id, departure_date DESC)` serves "this passenger's bookings,
newest first" in one index pass. `ix_bookings_flight`, `ix_routes_arrival_airport` and
`ix_routes_destination_airport` cover the join paths. PostgreSQL indexes primary keys
automatically but not foreign keys, so these are added by hand.

### Known limitations

Recorded rather than hidden; also covered in `analysis/unit2.md` §4.

- **`bookings.flight_route_id` has no foreign key.** It is `NOT NULL`, so every booking must
  carry a route id, but nothing requires that id to name a route that exists; any integer is
  accepted. Adding the constraint would also force `bookings` to be created *after*
  `flight_routes`, swapping positions 4 and 5.
- **Two constraints are misnamed.** `chk_airports_country` validates `code`, not `country`.
  `fk_routes_departure_airport` sits on a column called `destination_airport_id`; given the
  sibling column is `arrival_airport_id`, the column is the misnamed half.
- **`chk_bookings_flight_number` is a `NOT NULL` in disguise**: `CHECK (flight_number IS NOT
  NULL)` duplicates what a column-level `NOT NULL` would state more directly and enforce more
  cheaply.
- **`uq_routes_one_origin` is redundant.** It is a unique index on `flight_route_id`, which is
  already the primary key of `flight_routes` and therefore already unique.
- **The `DROP` block is not in reverse creation order**, despite the comment above it saying
  so. `CASCADE` makes the order immaterial, so nothing breaks.
