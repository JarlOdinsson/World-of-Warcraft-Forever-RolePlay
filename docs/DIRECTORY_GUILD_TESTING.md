# ForeverRP beta.11 guild test card

Build **0.1.1-beta.11 / directory-transport-20261010-11**.
All live scenarios here are **NOT RUN**. Use the same build on both clients.
Earlier test builds are superseded. Experimental networking and Directory participation are
OFF by default; cross-layer behavior is not established.

The independent shared-channel test is the cross-layer release gate:
[CROSS_LAYER_DIRECTORY_RETEST.md](CROSS_LAYER_DIRECTORY_RETEST.md). Party/guild
delivery alone does not pass it. Beta 11 adds transport evidence to /frp network.

## Setup and useful captures

1. Back up the old addon, install only one `ForeverRP` folder, and restart when
   adding the MP3. Leave WTF/SavedVariables untouched. Verify `/frp version` on
   both clients reports the build above; capture that output.
2. Start with discovery enabled, Visible privacy, Public profile disclosure,
   notifications enabled, no simulation. Keep experimental networking OFF for
   the first baseline. Use harmless distinct test profiles, never private notes.
3. Enable `/frp debug on`. Both capture `/frp network`, `/frp presence`,
   `/frp nearby` and `/frp diag Full Character Name-Realm` before/after a failure.
   Preserve real spaces and realm suffixes. Wait at least five seconds between
   diagnostics. Include Nearby/Directory screenshots and exact Lua errors.
4. Record time, party/guild membership, zone, privacy/disclosure/location settings,
   transport, whether players can target/interact, and any independently known
   phase/layer assignment. Do not infer different layers just from invisibility.
   Review captures for identities; never include biographies or private notes.

## 1. Preserve working discovery first

- Same party, same phase, standing together: both `/frp hello`; target/mouseover
  each other. Expected: presence accepted, usable matched unit, eligible range,
  Nearby row and one notification. Request profiles explicitly in Nearby.
- Stand still, then move within eligible range brackets. No repeated entry sound.
  Move out and back within cooldown: still no extra notification. Unknown range
  must not qualify. Capture bracket diagnostics if a stationary player flickers.
- Leave the party and test target/mouseover/nameplates without shared guild.
  Expected only where client unit observation and directed handshakes work.
  A bare nearby character is not proof of addon participation. If no match,
  capture send/receive → presence → unit → range → exclusion on both clients.
- Remember/Favorite, edit notes, switch selections, request profiles; verify notes
  survive. Check MingleBar actions/scale and minimap launcher left/right click/drag.
  NPC tooltips must not generate player discovery or restricted-value errors.

## 2. Opt-in directory and location

- On both, `/frp privacy`: enable Experimental Network, then independently enable
  Directory participation. Open `/frp directory`. Wait up to two minutes.
  Expected if metadata transport works: character entries, no automatic profile
  downloads. Don't share my location should show no zone/continent/subzone or marker.
- Choose Share zone only; then enable Subzone sharing. Expected permitted zone/subzone
  and continent if available, no precise marker. Region means continent.
- Set IC/LF RP/OOC; toggle client AFK and DND. Default lists only IC/LF RP with
  normal availability, expanded filter can include OOC/AFK, DND never appears.
  Removing AFK/DND must preserve the chosen RP state. Allow the normal bounded
  update interval; DND/opt-out attempts an immediate metadata withdrawal.
- Search full names including spaces; change status/zone filters. Expected local
  results without outgoing messages caused solely by filter edits. Opt out of
  Directory: remote row disappears after withdrawal or expiry; independent
  physical Nearby discovery must keep working.

## 3. Markers, zone changes, layers

- Enable precise location sharing and local markers. Same zone/coordinate space,
  within minimap view: expect a neutral noninteractive dot if delivery/coordinates
  work. Walk north/east; test rotating/nonrotating minimap and zoom. No profile
  opens/downloads on a dot; launcher remains usable.
- Stand stationary for three minutes: heartbeats should keep markers alive.
  Stop the peer client/network without clean withdrawal: marker expires after
  125 seconds since its last accepted coordinates; metadata after 150 seconds.
- Go to different zones: directory can retain permitted remote location; no
  remote-zone dot on your local minimap. No false physical Nearby entry.
- With independently verified different layers, repeat same-party/guild and
  unrelated-player tests separately. Record actual channels delivered. Directory
  data may arrive even with no targetable unit; that alone must not create Nearby.
  Layer label and marker stay Unknown/neutral in every case in this build.
  Missing delivery is a coverage limitation, not evidence of a different layer.

## 4. Privacy and transfer stress

- Approval Required: requester sees pending; owner Approves or Denies in Privacy.
  Unanswered prompt expires. No full profile may arrive before approval.
- Connections Only: Remember/Favorite alone fails; explicit grant succeeds.
  Forget or revoke grant stops future chunks. Test Visible/Restricted/Hidden too:
  being directory-listed never bypasses visibility or disclosure.
- Change sharing while a large profile is sending; recipient must not continue
  receiving newly forbidden chunks. Previously served updated clients should
  clear cache after content-free revocation or its five-minute lease.
- Leave guild/remove friend in Restricted mode, then wait through metadata ticks.
  Trust must not return from old GUILD packets. Repeat profile requests: no data.
- Three peers request large profiles concurrently: excess work may say busy.
  Retry later explicitly. No partial response should remain pending indefinitely.
- Toggle Hidden with an active directory/marker advertisement. Metadata goes
  away after withdrawal or its bounded stale interval. Restore Visible and
  re-request: an old revocation must not erase freshly authorized data.

## 5. Audio, persistence and population

- Settings: Bing Bong, Drumroll, None × Master/Sound Effects. Use Test Sound;
  repeat clicks quickly. Capture selected channel, audible outcome and any
  unconfirmed-preview message. None is silent. Preview works even when automatic
  sound is disabled; discovery respects notification settings. Global volume
  must remain unchanged. MP3/Master audibility is an explicit release gate.
- `/reload`, logout/login: verify sound, directory/location/subzone/marker and
  disclosure/grant settings, own profile, notes, MingleBar and launcher placement.
  Runtime remote profiles/directory data should repopulate, not persist as history.
- Moderate then crowded population: capture `/frp network` over a timed interval,
  responsiveness, duplicate alerts, queue timeouts and Lua errors. No filters
  should trigger profile floods. At caps incomplete coverage is expected; record
  it rather than treating the offline crowd test as proof of live scalability.
- Finish with `/frp debug off`. Send build ID, scenario, expected/actual behavior,
  both clients' minimal diagnostics and errors. No simulation as live evidence.

Hold public distribution until core discovery, privacy, UI and audio pass on the
actual Forever client. Keep cross-layer claims experimental until those tests
provide delivery evidence.
