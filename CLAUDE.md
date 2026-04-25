# Project: Jibsaja Project

## 🎯 Project Vision & Context
**What is this?**: A Flutter-based mobile app for asset tracking.
**Target Audience**: People who wish to track all their liquid asset and holdings.
**Problem it Solves**: Easily tracks assets, expenses, and holdings while syncing with excel asset dashboard.
**Core Philosophy**: The UI should feel "Premium and Minimalist." Speed of data entry is more important than flashy animations.

## 🗺️ Project Map
- **Firestore Schema**: [docs/data/firestore.md](docs/data/firestore.md)
- **Active Task State**: [HANDOVER.md](HANDOVER.md)
- **Rules**: Scoped rules in `.claude/rules/`

## 🛠️ Critical Dev Commands
- **Build**: `flutter build apk`
- **Tests**: `flutter test`
- **Analyze**: `flutter analyze` (Run this after every major change)

## 📜 Development Standards (The "Harness")
- **Architecture**: Use Clean Architecture (Data -> Domain -> Presentation).
- **State Management**: Riverpod.
- **Firestore**: 
  - Never use `Map<String, dynamic>` directly in the UI. 
  - ALWAYS use Model classes with `withConverter`.
  - Refer to `docs/data/firestore.md` before creating new queries.
- **Error Handling**: Use `Result` types (Success/Failure) for all Firebase calls.

## ⌨️ Shortcuts
- When I say `!bye`, it means: "Check for lint errors, update HANDOVER.md, and summarize next steps."

## 🔄 Persistence Protocol (Strict)
Before ending a session, you MUST update `HANDOVER.md`. Do not ask for permission; simply perform the write. Use this exact structure:
1. **Current Milestone**: High-level goal (e.g., "Auth Flow").
2. **Context & Logic Decisions**: Why did we choose a specific Riverpod provider? What Firestore trade-offs were made?
3. **The 'Gravel'**: List small, annoying bugs or half-finished refactors that aren't obvious from the code.
4. **Next Immediate Step**: The very first command or file the next session should touch.