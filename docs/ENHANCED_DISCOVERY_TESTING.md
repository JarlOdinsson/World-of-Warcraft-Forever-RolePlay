# beta.7 multiplayer test checklist

**Historical checklist. Use [the beta.8 guild checklist](DIRECTORY_GUILD_TESTING.md)
instead.** Beta.7 is superseded; its 45-second marker lifetime and separate activity
cache are no longer the current implementation.

Build: **0.1.1-beta.7 / discovery-consent-20261010-7**.
All live results below are **NOT RUN**. Offline tests do not establish delivery,
layer behavior, audio decoding, marker orientation or layout.

## Preparation and capture

1. Both testers install the same `ForeverRP-v0.1.1-beta.7.zip`, with exactly one
   `Interface/AddOns/ForeverRP/ForeverRP.toc`. Restart after first installation
   or adding the sound file. Back up the old addon; leave WTF/SavedVariables alone.
2. Each captures `/frp version`. Both must report the build above. Start Visible,
   discovery enabled, no simulation. Set profile disclosure Public initially.
3. On each client run `/frp debug on`, `/frp network`, `/frp presence`, and
   `/frp diag Full Character Name-Realm`. Preserve spaces and the actual realm.
   Diagnostic reports are rate-limited: wait at least five seconds between them.
4. Capture the same outputs after each test, plus the Nearby/Activity panels and
   any Lua error. Record timestamps, privacy, location setting, transport, phase,
   and whether both players can target/interact. Do not share biographies or notes.
   `/frp debug off` ends ordinary debug logging. `/frp sim` is only an offline-like
   developer tool and must not be used as evidence for these tests.

## A — Same layer, then unrelated players

- Stand together in the same party and phase. `/frp hello` on both; target and
  mouse over one another. Capture `/frp diag Peer Name-Realm`, `/frp presence`,
  `/frp nearby`. Expected: accepted presence, matched unit, eligible range,
  Nearby row and one entry alert. Request a profile through Nearby and verify it.
- Move between eligible brackets while standing near each other. Expected: no
  repeated entry alert. Move out, return within cooldown: no new sound.
- Enable Experimental Network on both in `/frp privacy`; choose Precise location
  and Minimap Markers ON. Wait up to two minutes. Expected if transport works:
  Activity row, neutral marker within minimap view radius, no clickable action
  or tooltip biography. Walk north/east, rotate and zoom the minimap, then switch
  zones. Verify marker direction, movement, stale removal (after 45 seconds)
  and no distant-zone markers. Unknown must remain Unknown even side by side.
- Leave the party; test outside a shared guild if possible. Keep network OFF first
  and test target/mouseover/nameplates for the existing directed handshake.
  Then turn the prototype ON and record whether the shared CHANNEL route actually
  works on this client. Neither success route proves invisible pass-by coverage.

## B — Independently confirmed different layers

- Use reliable external/client-supported evidence to establish the two layers;
  inability to see a player alone is insufficient. Record that evidence separately.
  Avoid forming a party that moves both testers onto one layer.
- Start in the same zone/coordinates using a shared guild route, then test without
  a shared guild/party using the experimental channel. Both must explicitly opt in.
- Expected only **if delivery is supported**: Activity receives the peer and remains
  Layer Unknown. Precise coordinates may draw a neutral marker; no unit means no
  Nearby entry and no physical-proximity notification. No green/blue classification.
- Record sender realm identifiers, routes, counter deltas and both diagnostic
  captures. Failure is an unresolved transport restriction, not proof to guess aliases.

## C — Different zones / backend scope

- Keep opted-in users in different zones. Test guild and shared-channel routes
  separately and, if available, different client-reported backend realm suffixes.
- If messages arrive, Activity groups current-zone peers first; no remote-zone
  minimap marker or Nearby claim. Zone-only sharing must never send coordinates;
  Location hidden must display Location hidden. There is no guaranteed server-wide
  registry or shared-channel scope; record actual behavior rather than assuming it.

## D — Profile and location privacy

- Public: a confirmed allowed requester receives the existing chunked profile.
- Approval Required: requester sees waiting; owner opens Privacy, Approves within
  25 seconds, and only then do chunks arrive. Repeat with Deny and with no response.
  Verify no biography arrives, no prompt flood and pending UI eventually clears.
- Connections Only: Remember/Favorite alone must deny. Owner explicitly Approves
  the saved Connection in Privacy; fresh request succeeds. Revoke or Forget while
  a long transfer is queued: further chunks stop. Verify private notes survive.
- After receiving a profile, owner tightens disclosure. Updated receiver clears
  cached profile on revocation. With the notice deliberately lost, cache expires
  after five minutes. Do not claim copied data or legacy caches can be retracted.
- Friends/Guild Only: strangers denied, verified guild/friend allowed. Switching
  from Visible leaves the shared channel. Hidden stops activity/location advertising
  and discovery/profile responses. A bounded content-free revocation may still be
  sent to an already-served peer. Unknown relationship never counts as trusted.
- Toggle location Precise → Zone → Hidden during queued sends. Receiver must stop
  showing precise markers on the next update/OFF, or at worst the 45-second expiry
  if a withdrawal is lost. Check `/reload` persistence on both characters/accounts.

## E — Audio

- In Settings select Bing Bong + Master, then Test Sound. Repeat on Sound Effects,
  legacy Drumroll and None. Record heard/not heard and any failure message.
- Repeat with existing game SFX mute/volume configurations; do not change global
  volume through the addon. Master may still follow the client's audio configuration.
  Failed or nil playback reports an unconfirmed preview, with no silent SFX fallback.
- Verify sound file loads after client restart. Existing users retain Drumroll until
  choosing Bing Bong; a fresh install defaults to Bing Bong. None stays silent.
- Preview clicks are separated by two seconds; preview works when automatic sounds
  are disabled. Automatic discovery respects disabled sounds, peer cooldown and
  eligible-bracket duplicate suppression. Confirm no unpleasant overlap or clipping.

## F — Busy event

- Start with 10, then as many consenting real clients as possible. Record `/frp network`
  before/after ten stationary minutes and ten moving minutes. Record routes per client.
- Repeat group/guild/zone events; verify no storms, UI stalls, repeating approvals
  or duplicate alerts. Try normal profiles, not continuous mass profile requests.
- Expected prototype limits: 30–40 seconds between useful announcements, 90–110
  second heartbeat, three routes/queued items maximum, two attempts per route,
  250 cached peers, 64 marker frames and 100 receive attempts/second. Traffic can
  multiply across routes and fan-out; compare actual counters to the report.
- Test combat, nameplate removal, phasing, disappearing target, minimap replacement
  addons and reload/logout. Unknown values must skip cleanly rather than qualify range.

## Results template

| Test | Both build IDs | Route / privacy | Expected | Actual | Evidence / error |
| --- | --- | --- | --- | --- | --- |
| A | pending | pending | associated unit + Nearby | NOT RUN | pending |
| B | pending | pending | metadata only if supported; layer Unknown | NOT RUN | pending |
| C | pending | pending | zone list, no distant markers | NOT RUN | pending |
| D | pending | pending | owner permission enforced | NOT RUN | pending |
| E | pending | pending | selected sound/channel or explicit limitation | NOT RUN | pending |
| F | pending | pending | bounded traffic and responsive UI | NOT RUN | pending |
