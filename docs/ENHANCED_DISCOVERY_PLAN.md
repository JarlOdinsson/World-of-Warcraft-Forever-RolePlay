# Enhanced discovery audit and implementation plan

Baseline: 0.1.1-beta.6, clean main at 05b7ba8. Existing discovery uses guarded
client unit identities, bounded directed WHISPER HELLO/ACK and group/guild
announcements. Presence expires after 900 seconds; Nearby separately requires
a usable associated unit and eligible interaction bracket. Raw transport
recipients remain separate from lookup keys. Profiles use confirmed-presence
requests, bounded chunk queues, per-peer cooldowns and retries. Connections and
notes are persistent; remote profiles are session-only. Notifications use
PlaySound with Master/SFX, but previously accepted nil as success.

## Critical blockers and limits

- Cross-layer delivery, shared-channel scope and physical layer identification
  are not verified by our live tests. Prototype networking must default off.
- No verified stable layer identifier is available. Records stay UNKNOWN; phase
  reason, invisible units, coordinates, backend realms and instance IDs are not
  layer IDs. Green/blue markers cannot honestly be enabled without evidence.
- A recipient can retain or copy previously disclosed data. Revocation can clear
  compliant runtime caches and stop new sends; it cannot retract those copies.
- The requested reference is spoken "BING BONG". YouTube playback was unavailable
  in research tools. The owner subsequently supplied nyc-bing-bong.mp3 and explicitly
  confirmed redistribution rights. Bundle those original bytes with a separate notice;
  do not claim an independently verified match to the video or decoded audio quality.
- The Forever branch documents C_Sound.PlaySound with a UISoundSubType and bool
  success; the shared implementation aliases PlaySound to C_Sound.PlaySound.
  This does not prove audible Master routing on the tester's particular client.

## Sequence

1. Restore developer commands as explicitly requested; keep logs free of profile
   contents/location payloads. Make audio results explicit and add sound choice.
2. Separate profile disclosure from visibility. Implement bounded owner approvals,
   explicit per-character connection grants and send-time/chunk-time enforcement.
3. Add opt-in location sharing and an isolated, off-by-default activity network
   using a distinct prefix. Never change legacy HELLO/ACK payloads or relay peers.
4. Render only valid nearby coordinates in the local coordinate space, using
   neutral markers while layers are unknown. No profile actions on marker clicks.
5. Add a zone-organized activity view, bounded counters, mocks, load analysis and
   a guild checklist. Package for testing only; no deployment/commit/push/release.

## API research

- https://raw.githubusercontent.com/Gethe/wow-ui-source/forever/Interface/AddOns/Blizzard_APIDocumentationGenerated/SoundDocumentation.lua
- https://raw.githubusercontent.com/Gethe/wow-ui-source/forever/Interface/AddOns/Blizzard_SharedXML/Mainline/Sound.lua
- https://raw.githubusercontent.com/Gethe/wow-ui-source/forever/Interface/AddOns/Blizzard_APIDocumentationGenerated/MinimapDocumentation.lua
- https://raw.githubusercontent.com/Gethe/wow-ui-source/forever/Interface/AddOns/Blizzard_APIDocumentationGenerated/ChatInfoDocumentation.lua

Generated API declarations establish signatures, not successful live transport,
audible playback, phasing behavior or coordinate projection on this beta client.
