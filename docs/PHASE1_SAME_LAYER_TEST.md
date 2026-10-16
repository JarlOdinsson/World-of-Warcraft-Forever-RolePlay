# Phase 1: two-player test gate

**Baseline:** `0.1.1-beta.20` / `profile-caret-20261016-20`.
**Live status:** On October 16, 2026 the maintainer reported stable behavior and
authorized release. The local chat pane and sound were explicitly reported working.
Individual results for the full checklist were not supplied; no assistant-run
multiplayer test is claimed. Retain these steps for repeatable regression testing.
Run one numbered step at a time; stop and capture a failure before changing code.
Both players should use the same ZIP.

Back up your installed ForeverRP folder, exit WoW, and replace that addon folder
with the ZIP's `ForeverRP` folder. Leave `WTF` and SavedVariables alone. Verify
`Interface/AddOns/ForeverRP/ForeverRP.toc` exists without a second nested folder.
Use `/frp version` on both clients after login.
Reports now appear in the local **ForeverRP** chat tab; also check
[the local-tab retest](BETA19_LOCAL_CHAT_RETEST.md).

Meet in an outdoor area and confirm you can see each other's characters moving.
Start ungrouped, preferably with two characters who do not share a guild.
Being in a party, guild or chat channel does not establish the same layer.
Set Discovery ON, Visibility Visible, radius 30, and Minimap Markers ON in Privacy.
Keep the Directory/network controls paused. Make both profiles Public for the
first pass. Enable a notification you can notice; use Test Sound separately.

| Step | Action on both clients | Expected result |
| --- | --- | --- |
| 1. Discover | Stand close; target or mouse over each other once, then check Nearby. Repeat with friendly nameplates if exposed by the client. | Both appear once, with the correct full name/realm. One entry alert; repeated target/mouseover does not spam alerts. A guild/party message alone must not create Nearby. |
| 2. Dots | While still close and targetable, walk a small circle; change minimap zoom, then test rotation on/off. Toggle markers off/on. | A neutral dot follows each qualifying player when the client supplies a safe position. Off hides all dots immediately; on reuses them. No profile opens or requests occur. If no safe position is available, no dot is drawn: record this as an unresolved dot-support limitation for that unit/context. |
| 3. Profiles and UI | Explicitly request each other's profile in Nearby. Hover the character; Remember them, add a private Connection note, and view/request through Connections. Open the menus and click one configured MingleBar action. | Native profiles complete in both directions with correct names. Tooltip display causes no automatic request. Notes stay local. Existing menus and MingleBar work without layout changes. |
| 4. Leave range | Walk well beyond 30 yards while retaining target where possible; return. Also clear target/mouseover/nameplate association. | Nearby and dots clear on the next one-second update when range is unknown/outside or no usable unit remains. Reentry within the notification cooldown does not alert again. Connections remain saved. |
| 5. Privacy | On A, test Approval Required: B requests; deny, then wait 10 seconds and request again and approve. Test Connections Only before/after Remember plus an explicit grant, then revoke. Test Hidden and Friends/Guild Only with an unrelated player. Repeat with roles swapped. | No full profile before approval/grant; Remember alone is insufficient. Changing privacy cancels disallowed queued chunks. Hidden suppresses new presence/profile replies and clears A's Nearby/dots. A restricted stranger is excluded; verified eligible friends/guild peers can work. Previously learned data on B follows the expiry limits below. |
| 6. Reload/relog | Restore Visible/Public. Each player runs `/reload`, then separately logs out and back in. Reobserve each other. Check profiles, notes, settings, MingleBar and disabled controls. | Saved personal data and layout persist; native discovery/profile requests resume. Old experimental opt-ins stay saved but cannot activate the network. Directory is empty and explains the pause. `/frp network` reports the pause. |
| 7. Combat | Enter combat; target/mouse over the other player, move, and change minimap zoom. Leave combat and reobserve. | No Lua errors or blocked-action notices. Range becomes Unknown and Nearby/dots clear; after combat they recover when safe range/position evidence returns. No repeated entry alert inside the cooldown. |
| 8. Expiry | With B logged out, keep A online for over 15 minutes. Check `/frp presence`, Nearby, dots and cached profiles. | B's presence expires without renewal. Nearby/dots already disappear when the unit/range disappears; profile caches expire within their existing five-minute lease. Saved Connection notes remain. |

Privacy timing: a Hidden client stops advertising/responding immediately, but
another client can retain previously confirmed presence for up to 15 minutes.
Previously served peers receive bounded cache revocations; lost revocations rely
on the five-minute cache lease. The native Beta 5 protocol has no immediate
presence-withdrawal packet. Hidden does not retract another person's copies.
Do not interpret a still-cached presence as fresh consent or verified proximity.

Repeat the essential discovery/profile/dot pass while grouped as well. A remote
or unobservable group member must not acquire a dot merely by joining the group.
Do not infer a layer number anywhere in this build.

If a step fails, collect **both clients'** `/frp version`, the numbered step,
approximate time, exact character names/realms, privacy/disclosure settings,
whether you could see/target each other, party/guild status, and the Lua error
or blocked-action text. For discovery use `/frp debug on`, reproduce once,
then `/frp diag Full Name-Realm`. For profiles also use `/frp diag profile`.
Capture the output before `/reload`, then `/frp debug off`. A screenshot of
Nearby, the minimap and the selected target helps with dot/range failures.
Do not include biographies or private Connection notes in a report.

**Exit gate:** both clients pass the relevant steps with existing privacy and
core features intact. Dot support for observable units, actual handshake/profile
delivery, combat/secret behavior, layout and audio are live gates, not proven by
offline tests. Do not publish this candidate as stable while those are unresolved.
