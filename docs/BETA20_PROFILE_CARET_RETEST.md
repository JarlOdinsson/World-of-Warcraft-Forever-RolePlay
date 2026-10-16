# Beta 20 profile cursor retest

Candidate: `0.1.1-beta.20` / `profile-caret-20261016-20`.

The user reported no visible blinking cursor in the long profile text boxes.
This candidate adds a white, two-unit-wide caret at the native cursor rectangle
and keeps that rectangle within the scrolling content. It does not replace the
client's text editing or selection. The underlying native rendering cause has
not been confirmed. The widget tests cannot verify the rendered result.

Test one step at a time:

1. `/reload`, open My Profile, and click Description. Type a few characters,
   then pause. Expect a white blinking line at the insertion point. Click in
   the middle of the text and use the arrow keys: the line should follow exactly.
2. Enter several wrapped lines, use Enter, and move between the top and bottom.
   Expect the cursor and current line to stay visible. Scroll manually and check
   the caret stays attached to its text, without drawing outside the box.
3. Click History. Only the focused field should show a caret. Repeat briefly in
   At a Glance and OOC Notes. Name and Title should behave as before.
4. Click away to save, reopen the profile, and confirm the text was retained.
   Make another temporary edit and press Escape: expect the previous saved text
   to return. Close/reopen the window; no caret should linger over another panel.

If anything fails, collect `/frp version`, the field name, the steps taken,
whether the text still changes, UI scale/chat font size, a screenshot showing
the insertion position, and any Lua error. Avoid sharing private profile text.

The scroll-coordinate convention was checked against the
[Ace3 multiline editor source](https://github.com/WoWUIDev/Ace3/blob/master/AceGUI-3.0/widgets/AceGUIWidget-MultiLineEditBox.lua).
This is a source reference, not proof of rendering on the Forever client.

Discovery/network behavior is unchanged from Beta 19. Location sharing has not
been restored. Continue the [Phase 1 live checklist](PHASE1_SAME_LAYER_TEST.md)
after this focused UI check; do not publish the candidate as stable.
