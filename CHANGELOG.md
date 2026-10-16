# Changelog

All notable user-facing changes to ForeverRP will be documented here.

## 0.1.1-beta.20 — profile-caret-20261016-20 (same-layer beta release package)

- Accepted by the maintainer as the same-layer beta baseline on October 16, 2026. This records maintainer release approval, not an independently observed multiplayer test or a claim that every checklist case passed.
- Since the last public Beta 5: retain the native same-layer discovery baseline with later privacy, identity-normalization, profile-transfer and combat/API guards. Keep the current menus, Connections, MingleBar, tooltips and notification controls.
- Include Beta 19's dedicated local ForeverRP chat tab for addon reports. It does not create a shared player channel or post these reports to General.
- Add a contrasting blinking caret to At a Glance, Description, History and OOC Notes, using the client's reported typing position, addressing the live report of an invisible native cursor in long profile text boxes.
- Stop caret updates when a field loses focus or is hidden. Preserve native typing, selection, Escape, saving, field limits and the existing layout; short profile fields are unchanged.
- Keep the actual cursor inside the scrolling content when wrapped text exceeds the estimated height. Unfocused field refreshes no longer move their inner scroll position.
- Minimap dots use fresh, independently qualified local unit positions when available. Location sharing, Directory, cross-layer advertisements, custom-channel recovery and layer inference remain disabled. Nearby-only position sharing is agreed future work, not included in this release.
- Automated validation: 24 Lua test suites, 77 Lua syntax checks, package structure and installed-file hash verification. Broader client-specific edge cases remain subject to beta feedback.

## 0.1.1-beta.19 — local-chat-20261014-19 (Phase 1 test candidate)

- Route ForeverRP notices, slash-command results, discovery text and enabled debug output to a dedicated local `ForeverRP` chat tab. These reports are not transmitted to other players.
- Reuse the saved tab across reloads without clearing its history or user filters; preserve the selected tab when creating it. The new tab starts without general chat/channel subscriptions.
- Buffer up to 100 startup lines until login. Defer tab creation during combat; if the tab cannot be opened (for example, chat slots are full), explain once and keep reports readable in the main local chat window.
- Retain Phase 1 discovery, privacy and profile behavior and the pause on Directory/cross-layer traffic. Add focused chat-output tests; live tab appearance/persistence still needs verification.

## 0.1.1-beta.18 — same-layer-phase1-20261014-18 (Phase 1 test candidate)

- Restore the Beta 5 native discovery path as the baseline for same-layer testing: observed-unit HELLO/ACK, confirmed presence, matching unit identity and conservative range checks. Guild/party receipts remain presence only; no layer is inferred.
- Archive Beta 17's Directory advertisements, custom-channel joins/recovery, layer inference and coordinate-advertisement markers outside the installable addon. Saved experimental preferences cannot enable these paths. Leave an existing `ForeverRPActivity` subscription once on login; do not register or send its addon prefix.
- Keep the current menus. Explain paused Directory, location/subzone sharing and network controls in their existing positions; retain profile permissions and explicit approvals.
- Preserve neutral, pooled minimap dots for confirmed Nearby players using fresh, visible local unit positions when safely available. No coordinate packets, cached remote coordinates or inferred layer labels. Missing/restricted positions, identity changes, unknown/out-of-range evidence and combat hide dots.
- Retain later privacy enforcement, native/MSP source separation, multiword identity and raw-recipient fixes, profile-transfer diagnostics and queues, notification cooldowns, combat guards, Connections and MingleBar.
- Add Phase 1 runtime regressions; retain historical experimental regression assertions against the archived modules. Package for two-player testing only. Live discovery, dots, profiles, privacy transitions, reload/relog, combat and UI/audio checks remain required before a stable release.

## 0.1.1-beta.11 — directory-transport-20261010-11 (controlled test build)

- Verify shared-channel membership rather than assuming a join call succeeded; retry at most three times per recovery cycle and rearm on bounded world transitions.
- Do not consume Directory announcements without a route. Drop stale channel-number/social routes and advertise new routes with the existing minimum interval.
- Expand `/frp network` with rate-limited membership, prefix, route, enqueue-result and valid remote-receipt evidence, without profile contents or notes.
- Test Directory discovery without mouseover, visible units or prior Nearby. Actual shared-channel/cross-layer delivery remains unverified; layer stays Unknown.
- Preserve opt-ins, privacy, existing A1/A2 packets and physical Nearby requirements.
- Post-build repair: prevent CheckInteractDistance calls during combat lockdown or without accessible out-of-combat evidence. Unavailable range remains Unknown; Directory and Nearby admission rules are preserved. Local live retesting reported no Lua error; broader combat validation remains pending.

## 0.1.1-beta.10 — privacy-clarity-20261010-10 (controlled test build)

- Directory lists each settings blocker: discovery disabled, Hidden visibility, Experimental Network OFF.
- Privacy shows read-only Discovery Visibility and explains saved network preference versus settings eligibility, without implying connection or delivery.
- Clarified location sharing and Directory Participation: withholding location or opting out of listing does not disable browsing.
- Status text refreshes immediately after relevant settings changes; privacy gates, defaults and saved keys are unchanged.

## 0.1.1-beta.9 — forever-names-transport-20261010-9 (controlled test build)

- Fixed bundled Chomp login/Battle.net name merging on Forever Interface 16001: the client display format no longer makes spaces inside a character name look like realm separators. Separate realms and distinct ClassicBetaPvE/ClassicBetaPvE2 keys are preserved.
- Added complete-unit-name evidence at bundled Chomp/LibMSP unit call sites. Kept the change client-scoped and used normal shared-library negotiation with a documented local compatibility revision; newer shared copies are not overwritten.
- Reproduced and repaired MSP name corruption that turned `Cletus Jenkins-ClassicBetaPvE` into `Cletus JenkinsClassicBetaPvE`, also covering Ellina Stillwind and Gladiator Trapgodx. This explains a concrete matching code path; actual live delivery remains unverified.
- Added bounded debug-only API-bound whisper recipient/source/result traces for ForeverRP discovery/profile sends and secure post-hook argument traces for shared MSP sends. Existing directed addressing, discovery limits and privacy checks remain intact; live player-not-found delivery failures are not claimed fixed.
- Left player-not-found system errors visible on Forever instead of registering Chomp's existing filter. Added real-library login, Battle.net cache, coexistence and exact outbound-recipient regressions plus a controlled retest guide.

## 0.1.1-beta.8 — directory-consent-20261010-8 (controlled test build)

- Reused the Activity panel for an explicitly opt-in RP Directory backed by the existing Presence cache. Added local character/zone/status filters, LF RP, separate temporary AFK/DND availability, optional subzones/continent information, and explicit existing profile requests. DND is excluded; OOC/AFK are hidden by default.
- Kept experimental networking disabled by default, all layers Unknown, and the existing Nearby unit/range pipeline intact. Added no library dependencies or message relays.
- Repaired audit failures: historical guild metadata restoring privacy trust, activity-cache eviction of legacy peers, approval transfers expiring behind large queues, unbounded/obsolete revocations, lost raw transport addresses, short stationary-marker lifetimes, and one-shot metadata prefix registration.
- Shared the existing Nearby lifecycle timer, bounded large-profile admission and cache-revocation history, and corrected rotating minimap projection. Retained the minimap launcher and user Settings spacing.
- Retained the exact supplied audio bytes at `Media/Sounds/nyc-bing-bong.mp3`, with explicit Master/SFX playback, preview and migration coverage. Actual audio behavior still requires client validation.
- Added directory, delayed-transfer, crowded-cache and combined discovery regressions, plus an updated architecture report and guild checklist. Offline validation does not prove live cross-layer discovery or release readiness.

## 0.1.1-beta.7 — discovery-consent-20261010-7 (superseded test build)

- Added separate Public, Approval Required and explicitly granted Connections Only profile disclosure. Enforced access before serialization and each chunk; bounded approvals, denials, revocation retries and five-minute remote cache leases.
- Added opt-in location privacy and an isolated experimental activity network, disabled by default. Cross-layer/shared-channel delivery is unverified; layer status remains Unknown.
- Added a zone-organized Activity panel and pooled, neutral, noninteractive minimap markers for recent valid volunteered coordinates. Existing Nearby qualification remains unchanged.
- Bundled the owner-supplied spoken Bing Bong recording with redistribution permission. Added Bing Bong/legacy Drumroll/None selection, preserved upgrade settings, tightened playback success handling and retained Master/SFX preview without changing global audio settings.
- Restored developer commands as requested and added aggregate network counters.
- Added mocked privacy, authorization, coordinate, marker, UI-action, traffic and sound regression coverage. This package requires live multiplayer/audio/UI testing and is not a verified cross-layer release.

## 0.1.1-beta

### Changed

- Updated compatibility for WoW: Forever 1.60.1 build 70170 (Interface 16001).

## 0.1.0-beta

### Added

- Initial CurseForge-compatible repository and release scaffolding.
- Validated PowerShell packaging and local installation workflows.
- Initial ForeverRP runtime bootstrap and startup lifecycle.
- Defensive account and character SavedVariables initialization.
- `/frp` and `/foreverrp` command handling for help, version, and debug settings.
- Optional account-wide debug logging, disabled by default.
- Native main window with Home and Settings navigation.
- Synchronized debug and minimap visibility settings.
- Draggable minimap button with persistent angle and localized tooltip.
- `/frp` window access and `/frp settings` navigation.
- Per-character local RP profile storage and editing.
- Plain-text single-line and scrollable multiline profile fields with limits.
- RP status selection for IC, OOC, AFK, and DND.
- Confirmed profile reset that preserves account settings.
- Profile completion count and `/frp profile` navigation.
- Minimap-first access with no automatically displayed main window.
- Read-only local Profile Viewer and `/frp view` navigation.
- ForeverRP addon communication protocol foundation.
- HELLO/ACK presence handshake over supported social addon channels.
- Session-only presence cache with 15-minute expiry.
- `/frp hello` and `/frp presence` testing commands.
- Debug-only protocol simulation commands for solo parser, handshake, validation, and presence-cache testing.
- Event-driven player-unit detection for nameplates, target, mouseover, focus, party, and raid units.
- Conservative range abstraction and configurable 10/15/20/25/30-yard discovery setting.
- Session-only Nearby qualification cache and `/frp nearby` diagnostics.
- Solo synthetic range simulation through the production Nearby logic.
- Nearby count badge attached to the existing minimap button.
- Configurable minimap pulse, subtle sound, and optional chat discovery feedback.
- Session-only per-character notification cooldown and duplicate suppression.
- Explicit simulator notification mode and cooldown reset commands.
- Safe PROFILE_REQUEST and chunked PROFILE_DATA protocol messages.
- Strict remote-profile schema validation, sanitization, and session-only caching.
- Read-only remote profiles in Profile Viewer and `/frp request <Name-Realm>`.
- Solo profile-transfer simulations for valid, malformed, oversized, and cleared data.
- Live Nearby panel with cached RP names, statuses, profile availability, and click-to-request viewing.
- Account-wide Visible, Friends/Guild Only, and Hidden discovery privacy modes.
- Centralized relationship checks for presence and profile transport, with conservative unknown handling.
- Debug simulator controls for privacy modes and simulated friend/guild relationships.
- Concise, duplicate-safe player tooltip details for confirmed ForeverRP users with cached profiles.
- First-beta documentation, command, persistence, protocol-boundary, and package-structure audit.
- MIT License for public source and addon distribution.

### Notes

- Prepared and validated the `0.1.0-beta` CurseForge archive.
- Initial Forever-specific interface metadata was verified against the then-current beta client and installed addon metadata.
- The CurseForge game-version identifier, project ID, and final in-game test pass remain release prerequisites.
