# ForeverRP Beta 20 — same-layer discovery baseline

This update focuses on reliable same-layer discovery while preserving the familiar ForeverRP interface.

- Keep RP profiles, Nearby, Connections, MingleBar, tooltips and configurable notifications.
- Retain later fixes for privacy, full character identities, profile transfers and combat-safe API handling.
- Send addon notices and command results to a dedicated local **ForeverRP** chat tab. These reports are not sent to General or a shared player channel.
- Add a visible blinking cursor to the long profile text boxes, including Description and History, with scrolling and focus handling.
- Keep minimap dots for confirmed Nearby players when the client supplies usable local positions.

**Temporarily unavailable:** RP Directory listings, cross-layer discovery, inferred layer numbers, shared-channel recovery, and zone/precise/subzone location sharing. Their controls remain in the existing menus with an explanation. Saved experimental preferences cannot restart this traffic.

Position sharing solely between independently verified Nearby players is planned, but is not part of this build. Existing privacy and profile-approval controls remain active.

For **World of Warcraft Forever 1.60.1** only. Update the `ForeverRP` folder inside `Interface/AddOns`, then `/reload`. Existing profiles and settings are retained. Range and minimap-position coverage depend on the client; unavailable information is not guessed, and combat can temporarily hide Nearby entries/dots.
