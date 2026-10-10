# Changelog

All notable user-facing changes to ForeverRP will be documented here.

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
