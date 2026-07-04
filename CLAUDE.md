# Project: Jibsaja Project

## 🎯 Project Vision & Context
**What is this?**: A Flutter mobile app that is a thin client for a Google Sheet.
It does exactly two things: **view** the transactions in the sheet, and **add rows**
to it (Purchase / Buy / Sell). No Firebase, no live price/FX feeds.
**Target Audience**: People who track assets/expenses in a Google Sheet dashboard.
**Core Philosophy**: The UI should feel "Premium and Minimalist." Speed of data entry is more important than flashy animations.

## 🗺️ Project Map
- **Sheet Schema & Backend Contract**: [docs/data/sheets.md](docs/data/sheets.md)
- **Active Task State**: [HANDOVER.md](HANDOVER.md)
- **Rules**: Scoped rules in `.claude/rules/`

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
- **Error Handling**: Use `Result` types (Success/Failure — `lib/domain/entities/result.dart`)
  for all Google Sheets calls.

## ⌨️ Shortcuts
- When I say `!bye`, it means: "Check for lint errors, update HANDOVER.md, and summarize next steps."

## 🔄 Persistence Protocol (Strict)
Before ending a session, you MUST update `HANDOVER.md`. Do not ask for permission; simply perform the write. Use this exact structure:
1. **Current Milestone**: High-level goal (e.g., "Auth Flow").
2. **Context & Logic Decisions**: Why did we choose a specific Riverpod provider? What Sheets/backend contract trade-offs were made?
3. **The 'Gravel'**: List small, annoying bugs or half-finished refactors that aren't obvious from the code.
4. **Next Immediate Step**: The very first command or file the next session should touch.