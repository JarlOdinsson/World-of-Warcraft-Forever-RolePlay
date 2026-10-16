# Beta 19: local chat tab

Candidate: `0.1.1-beta.19` / `local-chat-20261014-19`.
Scope: local report display only. No discovery transport or shared-channel change.

Run one step at a time:

1. `/reload`, then click the **ForeverRP** chat tab. Expect the loaded notice
   there. Run `/frp version`; expect Beta 19 and the build above in that tab,
   without a copy in General. Your previously selected tab should remain selected
   when the ForeverRP tab is first created.
2. `/reload` again. Expect one ForeverRP tab, retaining its placement and filters.
   Run `/frp debug on`, then `/frp debug off`; the command responses belong in
   the ForeverRP tab. Optional discovery text uses the same tab when enabled;
   sound/pulse settings and cooldowns are unchanged.
3. Continue the Phase 1 two-player checklist. Confirm the local-tab change does
   not affect discovery or profiles. Capture any Lua error plus `/frp version`
   and whether another addon manages your chat layout.

If all chat slots are occupied, or the client cannot create the window, a single
local explanation and subsequent reports appear in the main chat window. Free a
tab and `/reload` to retry. Creation is deferred during combat; an existing tab
can receive messages during combat. Startup buffering keeps the most recent
100 lines. Closing or renaming the dedicated tab can cause the same fallback
until reload; unrelated windows are never renamed or reconfigured.

Implementation reference: Blizzard's
[FloatingChatFrame implementation](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_ChatFrameBase/Mainline/FloatingChatFrame.lua)
provides the named-window creation API and no-default-channels option. The addon
also supports older chat-frame globals. That source is API guidance, not evidence
of live compatibility with the user's Forever client.

Automated tests mock chat APIs and forbid network sends. They do not establish
actual tab rendering, chat-addon coexistence or persistence in a live client.
