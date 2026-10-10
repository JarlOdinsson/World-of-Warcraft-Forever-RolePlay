# Cross-layer Directory controlled retest — Beta 11

Version: `0.1.1-beta.11`
Build: `directory-transport-20261010-11`
All live scenarios below are NOT RUN. Cross-layer Directory discovery remains a
release requirement, not a verified capability of this build.

## What is implemented

Valid A1/A2 metadata already travels directly from CHAT_MSG_ADDON through privacy
and identity checks into the shared presence record and Directory query. This path
does not require mouseover, target, nameplates, a remote unit, shared party/guild
or previous Nearby discovery. Directory participation must be enabled on the
advertiser to list it. A browser can keep its own participation OFF. Location is
independent and can remain withheld on both sides. No profiles are pulled merely
because metadata arrives.

Beta 11 repairs lifecycle gaps in that existing experimental transport:

- A join API call is no longer considered confirmed membership. GetChannelName
  must return an accessible positive integral local ID before CHANNEL is routed.
- Missing membership gets at most three join calls, ten seconds apart. Exhaustion
  stops retries until settings reset, reload, or a PLAYER_ENTERING_WORLD transition.
  World-transition rearming is rate limited to once per 30 seconds; repeated chat
  events cannot rearm it. Loss of previously observed membership starts recovery.
- Failed prefix registration remains bounded to three attempts and can recover
  after the same world-transition signal.
- No eligible routes means no consumed announcement or last-location state.
  A later valid route can announce without waiting for a no-route heartbeat.
- Numeric channel changes or departed social routes discard stale queued sends.
  Route changes preserve a minimum 30-second scheduling floor after the prior
  announcement. No new broadcast transport or visible chat fallback is added.
- Regular metadata has at most three queued routes (one group, guild, shared),
  at most two send attempts per route, existing token limits, one-second success
  spacing and ten-second failed-send spacing. Useful updates use 30–40-second
  scheduling; idle heartbeats use 90–110 seconds. Existing consent withdrawals
  and settings resets remain independently bounded by the existing token budget.
- /frp network reports build, eligibility, prefix, send API availability, observed
  membership/local channel ID, join attempts, current routes, queue depth, latest
  enqueue/result by route, and latest valid non-self remote metadata receipt by
  route with sender/channel metadata and age. Reports are limited to one per five
  seconds; no messages are sent by requesting a report. No profile/notes logged.
  Receipt records are historical evidence, not assertions of current membership
  or continuous connectivity. Raw ingress counters can include invalid packets;
  the new remote-receipt lines require accepted valid metadata.

Nearby still requires a confirmed peer plus usable unit identity and acceptable
range evidence. No physical proximity alert is fabricated from directory-only
metadata. Layer remains Unknown. Realm identifiers and multiword names retain
the existing identity handling; different backend realms are never merged.

## API evidence and limits

The [Forever branch generated ChatInfo API definitions](https://raw.githubusercontent.com/Gethe/wow-ui-source/forever/Interface/AddOns/Blizzard_APIDocumentationGenerated/ChatInfoDocumentation.lua)
show SendAddonMessage with a target and enum enqueue result, and CHAT_MSG_ADDON
with localID/name fields. They do not document which server transports span layers
or backend realms, and do not establish that CHANNEL is allowed on Forever.

[Blizzard's Classic 1.13.3 announcement](https://us.forums.blizzard.com/en/wow/t/wow-classic-patch-1133-lua-api-change/384543)
explicitly disabled CHANNEL addon messaging on that Classic version. This is a
material transport risk; applying it identically to Forever would be an assumption.
The existing opt-in CHANNEL path stays experimental pending real receive evidence.
A positive channel ID or result 0 alone cannot establish server delivery. There is
no supported global transport established by this source inspection. If this
client rejects or silently drops custom-channel packets, these repairs cannot
make it carry data; record that result instead of claiming cross-layer support.
No roster scraping, invisible-unit probing, unrestricted whisper fan-out, relaying,
ordinary chat fallback or restriction bypass was introduced.

## Tests: precisely what they prove

All 14 Lua 5.1 suites pass: 1,708 checks. All 45 runtime Lua files and 16 test/helper
Lua files pass luac -p; git diff --check passes.

The new suite has 12 cases / 122 assertions. It executes actual Activity,
Communication, Events, identity/privacy, Presence, Directory query and Nearby
code with mocked client APIs. It covers absent/delayed membership, exhausted
joins, bounded world-transition recovery, prefix failure/recovery, channel ID
changes, social route changes, exact numeric targets, retry limits, inaccessible
channel values, valid remote versus self receipt, expiry, no-profile/no-note
reports and report rate limiting. It preserves same-name multiword characters
on ClassicBetaPvE versus ClassicBetaPvE2 as distinct peers.

Two independent mocked addon states exchange actual serialized metadata through
an explicitly delivering bridge for five minutes, with no party/guild, visible
remote units, mouseover, or prior Nearby. Both obtain Directory rows and zero
Nearby rows, keep layer Unknown and location withheld, and honor listing opt-out.
This proves the code path when metadata arrives. The bridge has no layer server:
it does NOT prove transport support, joining on the real client, cross-layer or
backend-realm delivery, real channel event argument values, faction coverage,
profile delivery, large live population behavior, or actual minimap projection.
Existing identity, disclosure, transfer, privacy, UI, notification and simulation
regressions continue to pass. SavedVariables keys/defaults and opt-ins are unchanged.

## Solo preparation (not a cross-layer pass)

1. /reload; capture /frp version and confirm the build above.
2. Set discovery enabled and Visibility Visible in Settings. In Privacy enable
   Experimental Network deliberately. Location can stay Don't share my location.
3. Wait 30 seconds and capture /frp network. It should show membership=observed
   with a localID, prefix=true and a CHANNEL route if the APIs permit joining.
4. Capture again after two minutes. CHANNEL enqueue=accepted means enqueue only.
   No remote receipt is expected without another user. A self echo is deliberately
   excluded from remote evidence. Missing membership or enqueue rejection can be
   investigated solo; successful cross-layer discovery cannot be established solo.

## Exact independent two-client release test

Use the same ZIP on both clients. Record build, time, actual backend realm,
faction, zone, phase/layer evidence, privacy and Directory Participation settings.
Do not infer different layers solely from inability to see a player.

1. Both capture /frp version. For the independent test use no shared party/guild,
   no simulation, no target/mouseover/nameplate observation of one another. Enable
   discovery, Visible and Experimental Network on both. Set RP status IC or LF RP,
   DND/AFK off, advertiser Participation ON, location withheld initially. Keep
   profiles harmless and use no private-note contents in captures.
2. Establish a same-layer baseline without observing each other. /reload both
   after separating out of visible unit range to eliminate prior runtime presence.
   Open /frp directory, wait up to three minutes, and capture /frp network on BOTH.
   Capture /frp presence, /frp nearby and Directory screenshots too. Never run
   /frp hello as evidence of independent shared-channel discovery.
3. For a pass, each side needs a valid remote receipt CHANNEL with the other raw
   sender and a matching Directory row. GUILD/PARTY receipt alone does not pass.
   Different local channel numbers on the two clients are normal; those are local
   routing indexes. Remote-only peers must not enter Nearby or trigger proximity.
4. Repeat on independently established different layers. If grouping was used to
   move layers, leave the group and reload both after separation before measuring;
   shared-guild accounts cannot isolate CHANNEL coverage without recording that
   transport specifically. Preserve both complete /frp network outputs and row
   screenshots. Do not target/mouseover the peer to seed discovery.
5. Repeat same backend realm versus distinct backend realms separately. A pass
   between layers on one realm is not proof of cross-realm or cross-faction reach.
   Known different phasing is also a separate test, not proof of different layers.
6. On one side switch Participation OFF: the other listing should disappear after
   delivered withdrawal/update or the existing 150-second metadata expiry. The
   opted-out side must still browse. Switch Hidden or discovery/network OFF:
   no new advertisements; existing remote metadata expires if withdrawal is lost.
   Restore preferred settings afterward. Do not enable precise sharing just to
   run this test. Test zone/precise sharing separately only with explicit consent.
7. If CHANNEL is joined and sends are enqueued but neither side receives remote
   CHANNEL metadata, report that exact failure. If party/guild then succeeds,
   that narrows the problem to shared-channel coverage; it does not pass this gate.
   Stop release claims until supported independent transport is demonstrated.
8. Optional second stage: explicitly request profiles from directory-only peers
   under Public, Approval Required and Connections Only. Receipt must follow the
   existing disclosure controls. Directory delivery doesn't prove whisper/profile
   delivery. Check ordinary Nearby detection separately after the isolated test.

## Exact changed files

- ForeverRP/Discovery/Activity.lua: membership/recovery, route lifecycle and evidence.
- ForeverRP/Discovery/Communication.lua: forward addon channel metadata to Activity.
- ForeverRP/Core/Events.lua: preserve event arguments; signal world transitions.
- ForeverRP/Core/Commands.lua: rate-limit and extend existing network report.
- ForeverRP/Core/Constants.lua and ForeverRP/ForeverRP.toc: unique Beta 11 build.
- tests/directory_transport.lua: real-path transport/Directory regression checks.
- tests/discovery_diagnostics.lua and tests/public_commands.lua: build expectations.
- tests/README.md: suite invocation and evidence limits.
- README.md and ForeverRP/README.md: current build and transport limits.
- CHANGELOG.md: scoped Beta 11 changes.
- docs/DIRECTORY_GUILD_TESTING.md: current test build and cross-layer gate pointer.
- docs/CROSS_LAYER_DIRECTORY_RETEST.md: this audit/report and exact live procedure.

The working tree was clean at task start. No unrelated changes were discarded.
No UI layout, opt-in defaults, profile persistence, Connections, Chomp, MingleBar,
minimap projection or range logic changes. No CurseForge publication.

## Build/install verification

Built with tools/package.ps1 and installed with tools/install-local.ps1 using the
explicit verified destination:
`D:\Games\World of Warcraft\_classic_beta_\Interface\AddOns\ForeverRP`.
The actual installation contains WowB.exe. The prior 59-file addon was backed up
outside AddOns and hash-verified before replacement:
`D:\my build wow addons\ForeverRP\Backups\ForeverRP-before-beta.11-20261010-163619`.
All 59 installed files and all 59 ZIP files match packaging inputs by SHA-256,
including every TOC/Lua file matching development source. Existing root README
and LICENSE packaging overrides are preserved. WTF/SavedVariables untouched.

Package: `dist/ForeverRP-v0.1.1-beta.11.zip`
SHA-256: `8E41D6FC9DDE1D257E40F102E4BFA5220E13472AA442069E342A4A14FBE44978`
