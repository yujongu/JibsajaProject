# HANDOVER

## Current Milestone
**Test coverage — complete.** All six domain use cases now have unit tests. Total test suite: 125 tests, all passing.

## Context & Logic Decisions

- **Entity vs Model split**: Each Firestore-model class is split three ways:
  - `domain/entities/<x>.dart` — pure Dart, no Firebase imports.
  - `data/models/<x>_model.dart` — Firestore serialization + `fromEntity`/`toEntity`.
  - `presentation/extensions/<x>_ui.dart` — UI-only icon/color helpers.

- **Repository interfaces**: All repositories have `I<X>Repository` abstract interfaces in `domain/repositories/` with `<X>RepositoryImpl` in `data/repositories/`. Providers expose the interface.

- **Use cases**: `AddIncomeOrExpense`, `AddTrade`, `AddTransfer`, `ComputeAccountBalance`, `ComputeHoldings`, `CalculateNetWorth` under `domain/use_cases/`. `transaction_form_sheet.dart` calls all three `add*UseCaseProvider`s.

- **`AppUser` abstraction**: `domain/entities/app_user.dart` insulates domain from `firebase_auth`'s `User` type.

- **`AuthException` abstraction**: `domain/entities/auth_exception.dart` is a plain domain exception. `AuthRepositoryImpl.signIn/signUp` catches `FirebaseAuthException` internally and rethrows as `AuthException`. Auth pages import only `auth_exception.dart` — no `firebase_auth` in presentation.

- **`mapError` removed from `IAuthRepository`**: It was an implementation detail (Firebase error code mapping). It now lives as `_mapError` (private) inside `AuthRepositoryImpl`.

- **Router via Riverpod**: `appRouterProvider` (`Provider<GoRouter>`) reads `IAuthRepository` so `_AuthChangeNotifier` subscribes to `authStateChanges()` and `_redirect` uses `currentUser` — no direct `firebase_auth` in the router.

- **`firestoreProvider`**: `lib/presentation/providers/firebase_providers.dart` exports a single `Provider<FirebaseFirestore>`. All five repository providers (`account`, `card`, `holding`, `sync_settings`, `transaction`) receive their `FirebaseFirestore` via `ref.watch(firestoreProvider)` — no provider calls `FirebaseFirestore.instance` directly, so tests can override it with `FakeFirebaseFirestore`.

- **`Transaction` name collision**: Files importing both domain `Transaction` and `cloud_firestore` use `hide Transaction` or `as fs`.

- **Test strategy — no mockito**: Use-case tests use hand-written fake implementations of `ITransactionRepository` and `ISheetsSyncRepository` (inline in each test file). No `mockito`/`mocktail` dependency needed. Pure use cases (`ComputeAccountBalance`, `ComputeHoldings`, `CalculateNetWorth`) are tested directly with fixture data.

- **Tests**:
  - `test/data/models/` — model serialization (4 files, 79 tests).
  - `test/data/repositories/` — Firestore integration via `FakeFirebaseFirestore` (4 files).
  - `test/domain/use_cases/` — all 6 use cases (6 files, 46 tests). 125 total, all pass.

## The 'Gravel'

None known. The codebase is clean and fully analyzed.

## Next Immediate Step

Feature work. Candidates:

1. **Settings page** — `lib/presentation/pages/settings/settings_page.dart` likely has sign-out logic; verify it goes through `IAuthRepository.signOut()` and not Firebase directly.

2. **New feature** — refer to `docs/data/firestore.md` and follow the Clean Architecture workflow in `.claude/rules/clean_architecture.md`.

3. **Provider tests** — Riverpod providers in `lib/presentation/providers/` are not yet tested. Use `ProviderContainer` + `FakeFirebaseFirestore` overrides to cover async state.
