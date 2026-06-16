# USER_FEEDBACK_LOG — Isle

Chronological product/UX feedback (for agents). Include version when known.

---

## 2026-05-16 · v1.2.0+23–24

| Topic | Feedback | Status |
|-------|----------|--------|
| Feed UI | Everything grayed out; buttons invisible | Fixed: swipe coach dialog, setup banner disabled style, icon colors, version badge top overlap |
| Platform picker | Open YouTube/Brunch/blog from feed ⋮ | Done: `feed_platform_picker_sheet` |
| Brunch | Login persist, block authors | Done: WebView cookies + block scripts |
| Feed boost | While watching YouTube, want 「more like this」 — user chooses **channel** vs **genre**; save on phone for feed rank | Done: `feed_boost_sheet`, Hive store |
| YouTube back | Top-left back should go **back in YouTube**, not exit to feed | Done: `_handleYoutubeBack` |
| YouTube minimize | Swipe left edge / ↓ → feed with playback; **다시 보기** to rejoin; drag down trash to quit | Done: `YoutubeSession` + overlay |
| YouTube chrome | Top/bottom bars hide YouTube UI, Shorts, share sheets; video cropped | Done: immersive insets, no bottom chrome on YT, tap peek chrome |
| Version badge | Always show Isle name+version; tap copy; logs need version+time; agent replies end with version; bump on updates | Rules + v1.2.0+24 |
| Blueprint | No destructive refactors; trace before/after in `LATEST_CHANGES.md` | `.cursor/rules/isle-blueprint-and-release.mdc` |
| Brunch settings | Manage blocked authors list | Done v1.2.0+25 |
| Backup | feed boost + brunch block in survival export | Done schema 8 |
| Feed card boost | Thumb on YouTube feed cards | Done v1.2.0+25 |
| YouTube share/UI | Menu opens with chrome hidden; viewport CSS pad | Done v1.2.0+25 |
| Crash debugger | Persistent logs, copy all, crash timeline, survive kill | Done v1.2.0+26 |
| Draft autosave | 10+ min typing not lost; survival backup on pause | Done v1.2.0+26 |
| Feed grey | Setup banner dismiss; no blocking overlay | Done v1.2.0+26 |
