---
files: "lib/**/*.dart"
---

# Clean Architecture Standards: Jibsaja Project

## 🏗️ Layer Definitions & Boundaries
Every file must belong to one of these three layers. Dependencies MUST only point inwards.

### 1. Domain Layer (The Core)
**Path**: `lib/domain/`
**Responsibility**: Contains the "Truth" of the business. Pure Dart logic.
- **Entities**: Simple data classes (e.g., `Asset`, `Holding`).
- **Repositories (Interfaces)**: Abstract classes defining what the data can do (e.g., `abstract class IAssetRepository`).
- **Use Cases**: Specific business actions (e.g., `CalculateNetWorth`).
**STRICT RULE**: No imports from Flutter, networking packages, or other layers.

### 2. Data Layer (The Implementation)
**Path**: `lib/data/`
**Responsibility**: Retrieves and transforms data.
- **Models/DTOs**: Classes that handle JSON conversion (e.g., `SheetTransactionModel`).
- **Data Sources**: Direct communication with the Google Sheets web app (HTTP) or local cache.
- **Repository Implementations**: Where you write the actual code for the Domain Interfaces.
**STRICT RULE**: Must map Models to Entities using `.toEntity()` before passing data to the Domain layer.

### 3. Presentation Layer (The UI)
**Path**: `lib/presentation/`
**Responsibility**: Everything the user sees and touches.
- **Widgets**: UI components and screens.
- **State Management (Riverpod)**: Notifiers and Providers that manage UI state.
**STRICT RULE**: Never call the Sheets web app or other APIs directly. Only communicate with Domain Use Cases or Repository Interfaces via Riverpod.

## 🧱 The Dependency Rule
- **Domain** ⬅️ [Data] (Data depends on Domain)
- **Domain** ⬅️ [Presentation] (Presentation depends on Domain)
- **Data** ⇏ [Presentation] (Never mix these two)

## 🛠️ Implementation Workflow for New Features
When creating a new feature (e.g., "Excel Export"), Claude MUST follow this order:
1. Create the **Domain Entity**.
2. Define the **Repository Interface** in the Domain layer.
3. Create the **Data Model (DTO)** with JSON serialization for the Sheets contract.
4. Implement the **Repository** in the Data layer.
5. Create the **Riverpod Provider** to expose the Repository.
6. Build the **UI Widgets**.

## 🚫 Prohibitions
- DO NOT make HTTP calls (`package:http`) inside a Widget.
- DO NOT use `BuildContext` inside a Repository or Use Case.
- DO NOT import `package:flutter/material.dart` inside the Domain layer.