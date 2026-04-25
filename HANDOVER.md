# HANDOVER

## Current Milestone
**Clean Architecture migration — complete.** Codebase has been fully migrated from the old feature-first layout (`lib/features/*`, `lib/core/*`, `lib/shared/*`) to strict layer-first Clean Architecture (`lib/domain/`, `lib/data/`, `lib/presentation/`) as mandated by `CLAUDE.md`, `.claude/rules/clean_architecture.md`, and `.claude/rules/riverpod.md`.

Release APK builds cleanly. `flutter analyze` reports 0 errors (6 unrelated `DropdownButtonFormField.value` deprecation infos remain). 79/79 tests pass.

## Context & Logic Decisions

- **Entity vs Model split**: Each old bundled Firestore-model class was split three ways:
  - `domain/entities/<x>.dart` — pure Dart, no Firebase imports, holds business logic + `copyWith`.
  - `data/models/<x>_model.dart` — Firestore (`toMap`/`fromMap`) + `fromEntity`/`toEntity`.
  - `presentation/extensions/<x>_ui.dart` — UI-only icon/color helpers (separated from domain to keep domain free of `material.dart`).

- **Repository interfaces**: All repositories now have `I<X>Repository` abstract interfaces in `domain/repositories/` with concrete `<X>RepositoryImpl` classes in `data/repositories/`. Providers expose the **interface**, not the impl, so UI code depends only on the domain contract.

- **Use cases**: Added business-logic use cases (`ComputeAccountBalance`, `ComputeHoldings`, `CalculateNetWorth`, `AddIncomeOrExpense`, `AddTrade`, `AddTransfer`) under `domain/usecases/`. The form sheet still calls the repository directly in some places; use-case providers are wired and ready to be swapped in.

- **`AppUser` abstraction**: Introduced `domain/entities/app_user.dart` so domain never imports `firebase_auth`'s `User` type. `IAuthRepository.authStateChanges()` returns `Stream<AppUser?>`.

- **`Transaction` name collision**: Firestore's package also exports a `Transaction` class. Files that import both domain's `Transaction` and `cloud_firestore` use `import 'package:cloud_firestore/cloud_firestore.dart' hide Transaction;` or the alias `as fs` pattern.

- **Router note (pragmatic)**: `app_router.dart`'s `_AuthChangeNotifier` still talks to `FirebaseAuth.instance` directly rather than going through `IAuthRepository`. Functional, but worth revisiting — see Gravel below.

- **Tests reorganized**: `test/features/**` deleted; replaced with `test/data/models/*_test.dart` and `test/data/repositories/*_test.dart` mirroring the new structure. Tests now go through `<X>Model.fromEntity(entity).toMap()` and `<X>Model.fromMap(map).toEntity()`.

## The 'Gravel'

- **Router couples to `FirebaseAuth`**: `lib/presentation/shared/router/app_router.dart` imports `firebase_auth` directly in `_AuthChangeNotifier`. Clean-architecture-correct fix is to rewire it through `IAuthRepository`, but that needs more Riverpod plumbing (router has to read `authRepositoryProvider`). Deferred.

- **Auth pages still catch `FirebaseAuthException`**: `login_page.dart` / `register_page.dart` pattern-match on Firebase exception codes to show error messages. Proper fix needs a `Result<Success, Failure>` abstraction in the auth repository that carries a normalized error code; out of scope for the migration.

- **Use-case providers wired but unused**: `addIncomeOrExpenseUseCaseProvider`, `addTradeUseCaseProvider`, `addTransferUseCaseProvider` exist in `transaction_providers.dart`, but `transaction_form_sheet.dart` still calls `transactionRepositoryProvider` directly. Swap them in as a low-risk follow-up.

- **`DropdownButtonFormField.value` deprecation (6 sites in `transaction_form_sheet.dart`)**: Flutter deprecated `value:` in favor of `initialValue:` after v3.33.0-1.0.pre. Pre-existing, not caused by migration. Pure rename.

- **Old `test/widget_test.dart` is a stub**: Contains only `void main() {}` with a comment explaining full-app smoke tests need live Firebase. Still fine — just noting it's intentional.

## Next Immediate Step

Optional, low-risk follow-up: swap `transaction_form_sheet.dart` to use the three `add*UseCaseProvider`s instead of calling the repository directly. Files to touch:
- `lib/presentation/widgets/transactions/transaction_form_sheet.dart` — replace `ref.read(transactionRepositoryProvider).addTransaction(...)` etc. with `ref.read(addIncomeOrExpenseUseCaseProvider).call(...)`.

Alternatively, if you want to address the bigger gravel first, rewire `_AuthChangeNotifier` in `app_router.dart` through `IAuthRepository` to remove the last direct `firebase_auth` import in the presentation layer.
