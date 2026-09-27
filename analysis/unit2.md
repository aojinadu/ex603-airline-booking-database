# Unit 2 - Task 2.2: Reasoning Behind the Schema

**Theme 5: Airline Booking**
**Target DBMS:** PostgreSQL 14+ \
**Script:** `schema/schema.sql`\
**Author:** _Ayotola O. Jiandu_

Role mapping used throughout this document:

| Role | Table |
| --- | --- |
| actor | `passengers` |
| producer | `flights` |
| event | `bookings` (metric: `fare_paid`) |
| catalog | `airports` |
| junction | `flight_routes` |

---

## 1. The constraints table

One row per foreign key in `schema/schema.sql`.

| Foreign key | `ON DELETE` | Reason |
| --- | --- | --- |
| `fk_bookings_passenger` - `bookings.passenger_id` → `passengers.passenger_id` | `RESTRICT` | A passenger who has bookings represents money taken and a seat held, so the database refuses to erase the person while those commitments are still on file. |
| `fk_bookings_flight` - `bookings.flight_id` → `flights.flight_id` | `RESTRICT` | Deleting a flight that has sold seats would destroy the only record of what each passenger paid, so the flight cannot go until its bookings are dealt with. |
| `fk_routes_flight` - `flight_routes.flight_route_id` → `flights.flight_id` | `CASCADE` | A route row is nothing but the description of where that one flight goes; it has no meaning once the flight is gone, so it should disappear with it. |
| `fk_routes_departure_airport` - `flight_routes.destination_airport_id` → `airports.airport_id` | `RESTRICT` | An airport still serving as the departure point of a route must not vanish, or the route is left pointing at nothing. |
| `fk_routes_arrival_airport` - `flight_routes.arrival_airport_id` → `airports.airport_id` | `RESTRICT` | Same reasoning at the other end of the route: an airport in active use cannot be removed out from under it. |

All five foreign keys also carry `ON UPDATE CASCADE`. This is a low-stakes choice here because every parent key is a surrogate `INTEGER GENERATED ALWAYS AS IDENTITY` value that is never edited in normal operation. It costs nothing and means that if a key ever does have to be renumbered during a data migration, the children follow automatically instead of being orphaned mid-migration.

---

## 2. What each `ON DELETE` choice actually governs

### 2.1 `fk_bookings_passenger` - `RESTRICT`

**The real event.** A passenger asks for their account to be closed, or a staff member notices two records for the same person and tries to delete the duplicate.

**What happens on the platform.** The `DELETE` is refused outright. PostgreSQL raises a foreign key violation naming `fk_bookings_passenger`, and the transaction rolls back. To remove the person, staff must first resolve every booking attached to them - cancel it, refund it, or transfer it to the surviving record.

**Who is affected.** The passenger, whose paid-for seat would otherwise disappear while they still hold a confirmation. Finance, because `fare_paid` on those booking rows is the record of money actually received. And the other passengers on the same flight, because the seat count the airline believes it has sold would silently drop.

**What would go wrong under the alternative.** `CASCADE` is the dangerous option: one `DELETE FROM passengers` would silently take every one of that person's bookings with it. Revenue already collected would vanish from `SUM(fare_paid)` with no trace that it had ever been there, and nobody would be able to compute the refund owed, because the amount paid was in the row that was just deleted. The passenger would arrive at the airport holding a booking reference the database has never heard of. `SET NULL` is not available at all: `passenger_id` is declared `NOT NULL`, so the database would reject the attempt to null it - which is the correct outcome, since a booking with no passenger is not a booking.

### 2.2 `fk_bookings_flight` - `RESTRICT` (the producer case)

This is the constraint that answers *what actually happens when a producer is removed*.

**The real event.** A route is discontinued, a seasonal service ends, or an operations user tries to tidy up a flight record they believe is finished with.

**What happens on the platform.** Nothing is deleted. The database refuses the `DELETE` for as long as a single booking references that flight. The airline is forced down the correct path instead: cancel the flight as a business process, notify and rebook or refund each passenger, and only then - once no booking points at it - may the `flights` row itself be removed. In practice this means a flight that has ever sold a seat is effectively permanent unless someone deliberately clears its bookings first, which is the right default for a commercial record.

**Who is affected.** Every ticketed passenger on the flight. Finance, since `fare_paid` per booking is the revenue line for that service. Operations and reporting, because per-flight load and yield figures are computed from exactly these rows.

**What would go wrong under the alternative.** Under `CASCADE`, removing one row from `flights` would delete every booking ever made on it. The damage is quiet and total: passengers keep confirmation emails for bookings that no longer exist; refunds cannot be calculated because the fares are gone; and historical revenue for that flight simply drops out of every aggregate, so the airline's own reporting would show less money than it actually took, with nothing in the database to indicate a deletion had occurred. `RESTRICT` converts that silent data loss into a loud, immediate error at the moment someone attempts it.

### 2.3 `fk_routes_flight` - `CASCADE`

**The real event.** A flight is retired from the schedule, and - having already satisfied 2.2, so it carries no bookings - is removed.

**What happens on the platform.** Its `flight_routes` row is deleted along with it, in the same statement.

**Why this differs from the two above.** `flight_routes` is owned data, not a third-party commitment. Because `flight_route_id` is simultaneously the primary key of `flight_routes` and the foreign key to `flights.flight_id`, each flight has exactly one route row, and that row does nothing but say where that flight departs from and arrives at. Once the flight does not exist, the statement "this flight goes from A to B" is not merely orphaned, it is meaningless. A booking, by contrast, records something a customer did and money that changed hands; it outlives the thing it refers to and deserves protection.

**Who is affected.** Only internal scheduling data, and only for a flight that has already been established to have no bookings. The ordering of the two constraints matters here and is deliberate: `fk_bookings_flight` is checked as well, so the cascade can never fire on a flight with commercial history. Nothing a customer or the finance team relies on can be reached through this path.

**What would go wrong under the alternative.** `RESTRICT` here would buy no safety and add friction. Every flight retirement would fail on the route row, forcing staff to delete the route manually and then the flight - two statements, in an order they have to remember, to remove one logical thing. Worse, it invites the habit of deleting dependants by hand to get a delete to go through, which is exactly the habit that eventually gets pointed at `bookings`. `SET NULL` is impossible: the column is the table's primary key.

### 2.4 and 2.5 `fk_routes_departure_airport` and `fk_routes_arrival_airport` - `RESTRICT`

**The real event.** Catalogue maintenance. An airport was entered twice, or a small field closes, and someone tries to delete the `airports` row.

**What happens on the platform.** The delete is refused while any route uses that airport at either end. The correct procedure is a migration: re-point the affected routes at the surviving airport record, confirm none remain, then delete.

**Who is affected.** Every flight routed through that airport, and therefore transitively every passenger booked on those flights. `airports` is a catalogue: one row is referenced by many routes, so a single careless delete has reach far beyond the row itself.

**What would go wrong under the alternative.** `CASCADE` would be actively unsafe across two hops. Deleting one airport would delete the `flight_routes` rows that reference it - and since `bookings` is protected by `RESTRICT` and would survive, the result is flights that still have sold, paid-for seats but no itinerary at all: no departure point, no arrival point, nothing to display to the passenger or to the crew. The flight would still appear in every booking, and the airline would have no record of where it was supposed to go.

---

## 3. The `CHECK` constraints

### 3.1 `ck_passengers_firstname` - `CHECK (length(trim(firstname)) > 0)`
### 3.2 `ck_passengers_lastname` - `CHECK (length(trim(lastname)) > 0)`

**The unstorable state.** A passenger row that technically has a name but effectively does not: an empty string, or a value made only of spaces or tabs.

**How it could otherwise arise.** `NOT NULL` does not catch this, and that is the whole point of the pair. A web form submitted with the name box left blank posts an empty string, not `NULL`, and passes `NOT NULL` without complaint. A CSV import with a stray extra comma produces `''` in the wrong column. A mobile client that sends whatever is in the text field forwards the single space a user typed and deleted around. In every case `NOT NULL` is satisfied and the row lands.

**Why it matters.** The passenger name is what gets printed on a boarding pass and what appears on the flight manifest the airline is legally required to produce. A booking whose passenger cannot be identified at check-in is not recoverable at the gate - by then the person who could have corrected the typo is long gone. `trim()` is what makes the check meaningful rather than cosmetic: without it, a single space would pass.

### 3.3 `chk_flights_number` - `CHECK (flight_number ~ '^[A-Z0-9]{2}[0-9]{1,4}$')`

**The unstorable state.** A flight designator that is not in the shape the industry uses: a two-character airline code followed by one to four digits. This rejects `ba75` (lowercase), `BA 75` (embedded space), `BA123456` (too many digits), `B75` (one-character carrier code) and `''`.

**How it could otherwise arise.** Entirely through human entry. An operations user typing a schedule by hand does not shift-lock. A copy-paste from a PDF timetable brings a trailing space or a non-breaking space with it. 

### 3.4 `chk_airports_country` - `CHECK (code ~ '^[A-Z]{3}$')`

**The unstorable state.** An airport code that is not exactly three uppercase letters. This rejects `lhr`, `LH`, `LHRX`, `123` and `''`.

**How it could otherwise arise.** A typo during catalogue entry. Lowercase input from a form with no normalisation step.

### 3.5 `chk_bookings_fare` - `CHECK (fare_paid >= 0)`

**The unstorable state.** A booking recording a negative amount of money received.

**How it could otherwise arise.** The common route is a refund posted in the wrong place: rather than writing a separate credit record, a process updates the original booking to a negative figure to represent money going back out. A voucher or discount applied by subtraction with no floor can take a cheap fare below zero. A sign error in a bulk import from a payment provider flips a whole batch.

### 3.6 `chk_bookings_flight_number` - `CHECK (flight_number IS NOT NULL)`

**The unstorable state.** A booking that does not record the flight designator it was sold under.

**How it could otherwise arise.** The column is declared as plain `VARCHAR(8)` with no `NOT NULL`, so any insert that omits it would default to `NULL` and store happily. Without this check, a booking could exist with no designator on it at all.
