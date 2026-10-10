# Beta 10 — Discovery and Directory UX clarity

Version: `0.1.1-beta.10`
Build: `privacy-clarity-20261010-10`

This is an explanation-only update to the existing Privacy and Directory panels.
The pre-existing Activity:Enabled gate is unchanged. Networking eligibility still
requires discovery enabled, visibility other than Hidden, and Experimental Network
ON. Friends/Guild Only still uses existing relationship enforcement. No saved keys,
defaults, opt-ins, disclosure rules or transport/discovery algorithms change.

Directory reports every active blocker, in deterministic order:
1. Discovery disabled: enable discovery in Settings.
2. Hidden visibility blocks networking: Settings > Discovery Visibility.
3. Experimental Network OFF: enable in Privacy > Experimental Network.

Privacy shows read-only Discovery Visibility with Visible, Friends/Guild Only or
Hidden labels, and identifies Settings as the place to change it. The existing
network button shows the saved ON/OFF preference; the nearby status line shows
whether ON is paused by discovery disabled, Hidden visibility, or both. Eligible
settings do not assert connection or delivery.

Location choices now say Don't share my location, Share zone only, and Share
precise location. Help text distinguishes location withholding (browsing remains
possible) from Hidden visibility (networking blocked), and explains Directory
Participation OFF stops listing your character without disabling browsing.

Database setters refresh the existing Privacy and Directory UI immediately.
Panel switches continue to use the existing refresh path. Creation reads the
saved values. No polling timers or automatic settings changes were added.

## Exact changed files

- `ForeverRP/Core/Database.lua`: notify existing status UI after relevant setters.
- `ForeverRP/Discovery/Activity.lua`: read-only blocker/status explanations.
- `ForeverRP/UI/Activity.lua`: display each blocker instead of generic unavailability.
- `ForeverRP/UI/DiscoveryOptions.lua`: visibility/network status and consent labels.
- `ForeverRP/Core/Constants.lua`, `ForeverRP/ForeverRP.toc`: Beta 10 identifiers.
- `README.md`, `ForeverRP/README.md`, `CHANGELOG.md`: current labels/build notes.
- `tests/privacy_ux.lua`: 100 focused assertions using real modules and mock widgets.
- `tests/discovery_diagnostics.lua`, `tests/public_commands.lua`: build expectations.
- `tests/README.md`: new suite command and mock limits.
- `docs/BETA10_PRIVACY_UX_RETEST.md`: this report and retest checklist.

The checkout was clean before work. Settings.lua, its existing layout spacing,
Connections, MingleBar, Nearby, profile persistence, minimap, Chomp and identity
resolution were not edited.

## Validation

All 13 Lua 5.1 suites: 1,586 checks passed. All 45 runtime Lua files and all 15
test/helper Lua files pass luac -p. git diff --check passes. The new suite covers
all blocker combinations/order, saved preference versus eligibility, listing OFF
and location withheld with browsing enabled, Friends/Guild Only labels, immediate
setter refreshes on open panels, actual panel-switch refreshes, and saved-value
reinitialization/UI recreation as an offline /reload model.

Six-pixel glyph estimates and 12-pixel line estimates check unchanged button and
dropdown widths, compact status placement and explanation spacing. These are
mock layout checks, not rendered client font measurements. Live wrapping/scaling,
actual /reload and live delivery are not verified by these tests.

## Short in-game retest

1. `/reload`, then `/frp version`: verify Beta 10 / privacy-clarity-20261010-10.
2. With Experimental Network ON and Discovery Visibility Hidden, Privacy should
   show saved ON but paused by Hidden visibility. Directory should identify Hidden
   and point to Settings > Discovery Visibility.
3. Disable discovery and turn Experimental Network OFF too. Directory should
   list all three blockers in the order above. Re-enable one at a time and verify
   only that blocker disappears. No setting should enable another setting.
4. Check Privacy visibility labels for Visible, Friends/Guild Only and Hidden;
   switch panels and /reload. Verify saved preferences and current statuses agree.
5. With discovery enabled, Visible and Experimental Network ON, turn Directory
   Participation OFF and choose Don't share my location. Browsing should remain
   available; your character should not be listed and location stays withheld.
   A second consenting client is needed to verify your remote listing/location.
6. Check all three location labels and text wrapping at your normal UI scale and
   other supported scales. Check network status and participation button fit.
   Confirm Nearby/proximity, disclosure approvals, MingleBar and minimap behavior
   remain as before. Restore your preferred privacy settings after testing.

No CurseForge publication, release or tag is part of this task.

## Deployment verification

Installed using tools/install-local.ps1 with the explicit verified destination:
`D:\Games\World of Warcraft\_classic_beta_\Interface\AddOns\ForeverRP`.
`WowB.exe` exists in that installation. Before replacement, all 59 existing files
were copied and SHA-256 verified outside AddOns at:
`D:\my build wow addons\ForeverRP\Backups\ForeverRP-before-beta.10-20261010-151551`.
All 59 installed files and all 59 ZIP files match packaging inputs by SHA-256;
every installed TOC and Lua matches development source. Packaging uses root
README/LICENSE overrides as before. WTF/SavedVariables were not touched.

Package: `dist/ForeverRP-v0.1.1-beta.10.zip`
SHA-256: `A81764A8224DC65EEAAD89CB5EDC14044A18BA94C3DD0FEAA7C9754B0C8BFDB9`
