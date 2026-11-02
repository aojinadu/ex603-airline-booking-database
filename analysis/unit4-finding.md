# Unit 4 Finding: The Real No-Show Rate and Where It Comes From

**To:** Leadership team
**From:** Trust and Data team
**Re:** What the actual failure rate is, and which flights drive it

## The short answer

The real no-show rate across the platform is **6.3%**: 12 no-shows out of 192 bookings, once the 8 bookings that passengers cancelled themselves are set aside. That is about one booking in sixteen, not the one in two the old dashboard showed.

Most flights sit close to that figure. Among the busier flights (15 or more bookings each), the typical rate is about 5%. The problem is not spread evenly across the platform: a small number of flights account for a disproportionate share of no-shows.

## How it varies

**By flight.** Out of 13 flights with bookings, four had no no-shows at all, and most of the rest had one. Three flights stand out:

| Flight | Bookings | No-shows | Rate | Platform rate |
| --- | --- | --- | --- | --- |
| VN202 | 16 | 3 | 18.8% | 6.3% |
| VN203 | 13 | 2 | 16.7% | 6.3% |
| VN204 | 6 | 1 | 16.7% | 6.3% |

VN202 and VN203 together carry 5 of the 12 no-shows on the platform, while handling only about 15% of the bookings.

**By region.** Singapore (10.5%) and Japan (9.6%) run above the platform rate, Korea (5.6%) is close to it, and Thailand (4.2%) and Vietnam (0%) are below it. Japan's higher figure is driven mostly by VN202, which is based there.

**A note on small numbers.** The dataset is small, so a single no-show can move a flight's rate by several points. We only treat a flight as a concern when it has enough bookings for the rate to be meaningful, or when there is a second reason to look at it.

## What we would investigate

1. **VN202 (flight ID 2).** This is the clearest case. It has a normal volume of bookings (16) and a no-show rate three times the platform rate, and almost four times the 5% baseline for busy flights. The three no-shows came from three different passengers at different times of the year, so this looks like something about the flight itself (timing, route or how it is sold) rather than one unreliable traveller. This is the one to raise with the route manager first.

2. **VN203 (flight ID 3).** Two no-shows out of 12 is high, but the bigger concern is that this flight is marked as **inactive** and still holds 13 bookings. Five of those 13 did not end as a normal trip (two no-shows, two disputes and one passenger cancellation). Either the inactive flag is wrong or bookings were taken on a flight that was no longer running. Both are worth fixing, and the second could explain the no-shows.

3. **VN204 (flight ID 4)**, on watch rather than under investigation. Its 16.7% comes from one no-show out of six bookings. That is not enough to conclude anything yet, but it should be checked again once more bookings come in.

## Two data issues leadership should know about

- **Cancelled bookings have their fare set to zero.** All 34 cancelled bookings show a fare of 0.00, so the original price is lost. That pulls the average fare down (18.14 overall versus 21.92 for confirmed bookings) and means we cannot yet say how much money no-shows cost. We recommend keeping the original fare and recording refunds separately.
- **Inactive flights still carry bookings.** Besides VN203, flight VN209 is also marked inactive and has 14 bookings, including one no-show and two flight cancellations. The flight status data should be reviewed.

The supporting queries are in `queries/unit4/`, and the full working is in `analysis/unit4.md`.
