# HANDOVER — Jibsaja

**Live state only.** Rewrite this file in place each session; do not append. Anything that
outlives the next session belongs in `docs/` (see the map at the bottom).

_Last updated: 2026-08-26_

## Current Milestone

**Holdings filtered to KRW and USD only.** Shipped — committed and pushed to `main` on
2026-08-15 on top of `4b3e23e`.

Verified immediately before commit: `flutter analyze` clean, `dart analyze lib test` clean,
`flutter test` **238/238**. The APK at `build/app/outputs/flutter-apk/app-release.apk` was built
three minutes after the last source edit, so it carries the change.

Working tree is clean. Nothing is blocked.

## Next Immediate Step

**Run the on-device backlog.** Six consecutive milestones shipped without a device pass — all
deliberate, all settled by installing the one APK already on disk and working down this list.

| Milestone | Commit | On-device |
|---|---|---|
| Holdings filtered to KRW/USD | `4b3e23e`+ | ❌ |
| Holdings tab | `4b3e23e` | ❌ |
| Appearance: System/Light/Dark | `73cd155` | ❌ |
| Category drill-down + Accounts freshness | `06bd23b` | ❌ |
| Expense rows colored by category | `29cf9b1` | ❌ |
| Accounts tab | `e653ed2` | ❌ |

The three checks that matter most:

1. **Count the Holdings rows against the sheet.** Every row whose `Currency` is `KRW` or `USD`
   appears and nothing else does. A row you expected but cannot find means its `Currency` cell is
   blank or misspelled — **fix the sheet, not the app** (see `docs/gotchas.md`).
2. **Check USD amounts outside the new tab.** They now read `$45.30` rather than `$45.3` on the
   Transactions list, the summary card, category drill-downs and USD account balances.
   **Nothing ₩ may change.** One-line revert plus `money_test.dart` if it looks wrong.
3. **Check Holdings figures against columns C–H**, the derived percentage against column I, the
   sort header's four columns and reverse-on-re-tap, and blank cells showing **—**.

**Do not tap Add while verifying** — all six milestones are read-only.

If everything reads right, clear this table and the tree is fully settled for the first time in
six milestones.

## Where things live

| What | Where |
|---|---|
| Architecture, commands, conventions | `CLAUDE.md` |
| Scoped rules (Clean Architecture, Riverpod) | `.claude/rules/` |
| Sheet schema & backend contract | `docs/data/sheets.md` |
| Traps that still bite, and known dead code | `docs/gotchas.md` |
| Why past decisions were made | `docs/handover-archive.md` (closed 2026-08-15) |
