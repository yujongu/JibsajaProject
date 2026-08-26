# Project: Jibsaja Project

## 🎯 Project Vision & Context
**What is this?**: A Flutter mobile app that is a thin client for a Google Sheet.
It does exactly two things: **view** the transactions in the sheet, and **add rows**
to it (Purchase / Buy / Sell). No Firebase, no live price/FX feeds
(`firebase.json`/`firestore.rules` are unused leftovers from an earlier scaffold — ignore/remove them).
**Target Audience**: People who track assets/expenses in a Google Sheet dashboard.
**Core Philosophy**: The UI should feel "Premium and Minimalist." Speed of data entry is more important than flashy animations.

## 🗺️ Project Map
- **Sheet Schema & Backend Contract**: [docs/data/sheets.md](docs/data/sheets.md)
- **Active Task State**: [HANDOVER.md](HANDOVER.md)
- **Rules**: Scoped rules in `.claude/rules/`
- **Gotchas & dead code**: [docs/gotchas.md](docs/gotchas.md)
- **Past decisions**: [docs/handover-archive.md](docs/handover-archive.md) (closed)

## 🛠️ Critical Dev Commands
- **First-time setup**: `cp lib/core/config/app_config.template.dart lib/core/config/app_config.dart`,
  then fill in `sheetsWebAppUrl` + `sheetsApiKey`. The file is gitignored — never commit real values.
  ⚠️ An empty `sheetsWebAppUrl` disables Sheets sync *silently*.
- **Build**: `flutter build apk`
- **Tests**: `flutter test`
- **Analyze**: `flutter analyze` (Run this after every major change)

## 📜 Development Standards (The "Harness")
- **Architecture**: Use Clean Architecture (Data -> Domain -> Presentation).
- **State Management**: Riverpod.
- **Google Sheets**:
  - Never use `Map<String, dynamic>` directly in the UI.
  - ALWAYS map JSON to/from the `SheetTransaction` entity via `SheetTransactionModel`.
  - Refer to `docs/data/sheets.md` before changing the column layout or backend contract.
  - The sheet endpoint is **not** fixed by `app_config.dart` alone: it only seeds
    the "Test" profile on first run. Both "Test"/"Real" slots + the active one
    live in `SheetProfileStore` (SharedPreferences) and are edited at runtime
    via Settings — see `sheet_profile_providers.dart`.
- **Error Handling**: Use `Result` types (Success/Failure — `lib/domain/entities/result.dart`)
  for all Google Sheets calls.

## ⌨️ Shortcuts
- When I say `!bye`, it means: "Check for lint errors, update HANDOVER.md, and summarize next steps."