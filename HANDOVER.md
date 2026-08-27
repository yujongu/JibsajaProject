# HANDOVER — Jibsaja

**Live state only.** Rewrite this file in place each session; do not append. Anything that
outlives the next session belongs in `docs/` (see the map at the bottom).

_Last updated: 2026-08-27_

## Current Milestone

**Transaction rows redesigned so the category is readable as words.** Implemented, **uncommitted**.

The old row spent its only text badge on the *type* ("Purchase" on every expense) and left the
category to hue and glyph alone — 12 categories, 12 hues, no words. `TransactionTile` is now a
category-tinted card split into a deeper identity block (icon over label) and the description,
account, date and amount. Chosen from four rounds of HTML mockups in `docs/design/`.

Three decisions worth knowing before changing it:

- **The block has no fixed width.** It measures the widest of the 16 labels it can ever hold at
  the current `TextScaler`, so it follows the phone's text-size setting instead of clipping.
  See `docs/gotchas.md` → UI & layout for the consequences.
- **Tint is two steps of the category hue** over the card, tuned per theme: **15%/28% light**,
  **15%/26% dark**. Dark was lowered a step after seeing it on a device — the heavier wash that
  looked right in the mockups turned the rows into slabs of colour on the navy card.
- **`_typeColor` now takes `isDark`** and returns light/dark pairs. Buy (`#0055B2`) and Deposit
  (`#059669`) were single constants sitting nearly unreadably dark on the navy card.

## State of the working tree

Uncommitted:

| Path | What |
|---|---|
| `lib/presentation/shared/widgets/transaction_tile.dart` | modified — the redesign |
| `test/presentation/shared/widgets/transaction_tile_test.dart` | new — 12 tests, mutation-checked (see below) |
| `docs/design/*.html` | new — the four mockup rounds, published as Artifacts |
| `docs/gotchas.md` | modified — intl `TextDirection` trap, block-width behaviour, diverged `_typeColor`, the two text-scale traps below |

Verified 2026-08-27, after the last source edit: `flutter analyze` **clean**, `flutter test`
**255/255** (243 before this session + 12 new).

**Seen running** on an iOS simulator (iPhone 17 Pro, iOS 26.5) against the real sheet, July 2026.
The width rule holds: blocks widen with the platform text size, stay uniform across rows, and stop
at the 30% cap with `TRANSFER` ellipsizing to `TRAN…`. Text scale was driven with
`xcrun simctl ui <udid> content_size <category>`, which Flutter picks up live — no restart.

That run found one real defect, now fixed: **the amount starved the description** at accessibility
scales (non-flex Row child taking its full intrinsic width; `RenderFlex overflowed by 285 pixels`).
It is bounded by `_amountMaxShare` and covered by a test that fails without the cap.

**Dark mode is verified too** — the app defaults to `ThemeMode.system`, so
`xcrun simctl ui <udid> appearance dark` was enough. Rows read correctly in both themes at
default and accessibility text sizes.

Measuring that run found a second defect, also fixed: the label was drawn in the **same hue as
the block behind it**, costing most of its contrast (1.73:1 at worst). It is now mixed 45% toward
the theme's text colour — see `docs/gotchas.md`. Both themes re-checked on the simulator after
the change.

A subagent review then found the tests were far weaker than they looked: the contrast test read
the *body* wash rather than the block (it passed with the block painted in the raw hue), and the
width tests passed against a gutted measurement. Both are fixed and the suite is now
mutation-checked — painting the block in the raw hue, dropping the type labels from the measured
set, and taking the first label instead of the widest each fail it. The same review found the
block ground was painted with `Positioned(left:)` behind a directional `Row`, which put it on the
wrong side under RTL; it is now `PositionedDirectional`.

`category_detail_page.dart` shares the tile and was checked on the simulator too: it is filtered
to one category, so every row's block repeated the same icon and word — a fact the page's title
and header already state. It now passes `showIdentity: false`, keeping the tint and giving the
description the block's width back.

## Next Immediate Step

**Commit** — the tree has been clean since `45168cb` and this is one self-contained change,
now verified in both themes at both text-size extremes.

Two **pre-existing** overflows became visible during the run and are recorded in `docs/gotchas.md`:
`_SummaryHeader` overflows right, and `main.dart`'s `_BottomNav` overflows ~112px, both only at
accessibility text scales. Neither was touched.

The **on-device backlog from the previous session is still unrun** (six shipped milestones never
verified on a real device, listed in `git show 45168cb:HANDOVER.md`). A simulator pass is not an
Android device pass; the APK on disk predates all of this.

## Where things live

| What | Where |
|---|---|
| Architecture, commands, conventions | `CLAUDE.md` |
| Scoped rules (Clean Architecture, Riverpod) | `.claude/rules/` |
| Sheet schema & backend contract | `docs/data/sheets.md` |
| Traps that still bite, and known dead code | `docs/gotchas.md` |
| Row design explorations (HTML) | `docs/design/` |
| Why past decisions were made | `docs/handover-archive.md` (closed 2026-08-15) |
