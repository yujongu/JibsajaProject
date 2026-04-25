---
files: "lib/presentation/**/*.dart, lib/providers/**/*.dart"
---

# Riverpod Coding Standards: Jibsaja Project

## 🏗️ Architecture
- All Providers must reside in the **Presentation** or **Application** layer.
- Never place business logic directly in the Widget; delegate to a `Notifier`.

## 🛠️ Implementation Rules
- **Naming**: Providers should be named `[feature]Provider` (e.g., `assetListProvider`).
- **Async Data**: Always use `AsyncValue` to handle loading and error states. 
- **Code Generation**: [Decide if you use @riverpod generator or manual. If using generator, add: "Always use the @riverpod annotation and run build_runner."]
- **Immutability**: All state classes must be immutable (use `freezed` or `copyWith`).

## 🎨 UI Integration (Premium & Minimalist)
- Every `AsyncValue` must handle `.when()` explicitly.
- **Loading**: Use a subtle `Shimmer` effect or a minimal linear progress bar, never a generic full-screen spinner.
- **Error**: Log errors to the console and show a user-friendly SnackBar rather than breaking the UI.

## 🚫 Prohibitions
- DO NOT use `ref.read` inside the `build` method of a widget.
- DO NOT use `watch` inside a button's `onPressed` callback; use `read`.