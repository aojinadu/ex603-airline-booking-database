# Unit 3 Finding: The No-Show Rate on the Booking Dashboard

**To:** Dashboard team
**From:** Trust and Data team
**Re:** The "about half of bookings end in a no-show" figure

The dashboard reported that about half of all bookings (46%) end with the passenger not showing up, and on that basis the route profitability review was frozen. The data does not support that figure. Of the 200 bookings on record, 12 were passenger no-shows. Leaving out the 8 bookings that passengers cancelled themselves, as the dashboard intended, that is 12 out of 192 bookings, or about 6%. That is roughly one booking in sixteen, not one in two, and it fits what the route manager who questioned the number has seen in practice.

The error came from how the dashboard decided which bookings to count. It was meant to count every booking except the ones a passenger cancelled. But only cancelled bookings carry a cancellation reason; a normal completed booking has that field left blank. The rule the dashboard used treated "blank" as "unknown" rather than "not a passenger cancellation," so it quietly threw away every one of the 166 bookings with no cancellation reason, which is every completed and every disputed booking. The dashboard was left measuring no-shows among 26 cancelled bookings only, and in that small group no-shows really are close to half. Nothing crashed and the number looked plausible, which is why nobody noticed that most of the bookings had disappeared from the count.

We recommend lifting the freeze on the route profitability review and re-running it with the corrected figure of about 6%. The dashboard calculation has been fixed so that bookings with no cancellation reason are counted, and we have checked the fix against the full table. Separately, 10 bookings are currently marked as disputed; they are not no-shows and should be resolved through the normal dispute process rather than counted as failures.
