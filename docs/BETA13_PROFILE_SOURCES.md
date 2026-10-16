# Beta 13 profile source repair

Version `0.1.1-beta.13`, build `profile-source-20261010-13`.

Confirmed code defects:

- MSP protocol-only responses became blank profiles with default OOC and
  unconditionally opened the viewer. No FRP profile was overwritten in storage,
  but the callback could select MSP before FRP completed.
- FRP transfer IDs matched case-insensitively, while presence admission of profile
  packets and runtime cache lookup used exact case. An equivalent full identity
  could be rejected or miss a stored profile. This reproduces offline; the live
  report does not establish that the tester's sender casing differed.
- Connection controls were hidden whenever any MSP cache existed for the peer,
  even when the displayed source was FRP.

Trace: Nearby/Connections/slash request -> ResolveKnownKey -> PROFILE_REQUEST
sent to stored raw sender -> pending transfer keyed by lowercase full identity
and message ID -> PROFILE_DATA privacy/confirmed-peer admission -> chunk assembly
and validation -> RemoteProfiles storage -> ShowRemote -> viewer selects FRP
before MSP. No transport recipient, realm alias or privacy rule was changed.

Fixes: profile/control packets resolve against the case-equivalent full confirmed
identity before admission. FRP/MSP caches match case-equivalent complete keys
without merging realm suffixes. Empty MSP data is rejected; meaningful MSP data
stays separate and does not open over a pending or cached FRP profile. Explicit
MSP opens also prefer FRP. Connection controls follow the displayed source. MSP
reads enforce existing privacy access. Meaningful MSP-only profiles still work.

Incremental files for this repair (prior Beta 12 work preserved):

- `ForeverRP/Discovery/Communication.lua`
- `ForeverRP/Discovery/MSPCompatibility.lua`
- `ForeverRP/Profile/RemoteProfiles.lua`
- `ForeverRP/Profile/ProfileViewer.lua`
- `tests/profile_sources.lua` (new), `tests/msp_compatibility.lua`, `tests/README.md`
- Build identity: `ForeverRP/Core/Constants.lua`, `ForeverRP/ForeverRP.toc`,
  `tests/public_commands.lua`, `tests/discovery_diagnostics.lua`
- `README.md`, `ForeverRP/README.md`, this report

Validation: all 16 Lua 5.1 suites pass, 2,112 checks total, including 94 new checks.
All 45 runtime and 18 test/helper Lua files compile; whitespace checks pass.
The regression uses actual request serialization, incoming packet parsing,
transfer assembly, caches and viewer selection with mocked client APIs/widgets.
It covers empty and populated MSP arriving before/after FRP, pending FRP requests,
case-equivalent multiword identities, distinct realm suffixes, unchanged raw
request recipients, local-profile isolation, displayed-source controls and Hidden
privacy. Mocked reception/rendering does not prove live delivery or visual layout.

Live retest after installing Beta 13:

1. `/reload` and `/frp version` on both clients; confirm Beta 13/build above.
2. Confirm each other in Nearby. Request Putrick's completed FRP profile. Expect
   the actual fields/status and no `(MSP)` label; keep the viewer open and
   target/mouse over him again. The FRP view and Remember controls should remain.
3. Repeat with the opposite arrival order by targeting before requesting the FRP
   profile. Protocol-only MSP data must not open a blank OOC viewer.
4. If FRP fields still do not arrive, capture `/frp diag` and debug send traces;
   this patch does not prove the remote profile response was delivered/approved.

Local installation is authorized for this repair. No GitHub push/publication.
