# youtogether-frontend

Flutter client application for the YouTogether platform - 
a synchronized watch party application enabling groups of users 
to watch YouTube videos together in real time.

This repository contains the frontend application only. 
Backend services are maintained in [`youtogether-backend`](https://github.com/YouTogether/youtogether-backend). 
Project management artifacts and planning documents are maintained in [`youtogether-project`](https://github.com/YouTogether/youtogether-project).

---

## Table of Contents

- [Architecture](#architecture)
- [Bounded Contexts](#bounded-contexts)
- [Prerequisites](#prerequisites)
- [Getting Started](#getting-started)
- [Git Hooks](#git-hooks)
- [Running Tests](#running-tests)
- [CI Pipeline](#ci-pipeline)
- [Release Process](#release-process)
- [Contributing — Issue Creation](#contributing--issue-creation)
- [Labels Reference](#labels-reference)

---

## Architecture

The application follows **Clean Architecture** with **BLoC** as the state management pattern. The codebase is structured in three distinct layers with strict unidirectional dependency rules:

```
lib/
  core/                        # Shared utilities, error handling, network client
  features/
    <feature>/
      domain/                  # Entities, repository interfaces, use cases
      data/                    # Repository implementations, models, data sources
      presentation/            # BLoC / Cubit, pages, widgets
```

Dependencies flow inward: `presentation` depends on `domain`; `data` depends on `domain`; `domain` depends on nothing outside itself.

All implementations follow **Test-Driven Development** (tests written before production code) and **Domain-Driven Design** (code organized around bounded contexts).

Interface contracts for all layers are defined in the [Interface Contracts document](https://github.com/YouTogether/youtogether-project/blob/main/docs/architecture/interface-contracts.md).

---

## Bounded Contexts

| Context                   | Scope                                                                       |
|---------------------------|-----------------------------------------------------------------------------|
| **Authentication**        | Account registration, login, session persistence, token refresh, logout     |
| **Room**                  | Room creation, listing, membership, ownership enforcement                   |
| **Video Synchronisation** | YouTube IFrame player, Firebase real-time playback state, presence tracking |

---

## Prerequisites

| Tool        | Version              | Notes                                                              |
|-------------|----------------------|--------------------------------------------------------------------|
| Flutter SDK | 3.x (stable channel) | [Installation guide](https://docs.flutter.dev/get-started/install) |
| Dart SDK    | Bundled with Flutter | —                                                                  |
| lefthook    | Latest               | Git hooks manager — see [Git Hooks](#git-hooks)                    |

To verify your Flutter installation:

```bash
flutter doctor
```

---

## Getting Started

```bash
# Clone the repository
git clone https://github.com/YouTogether/youtogether-frontend.git
cd youtogether-frontend

# Install Flutter dependencies
flutter pub get

# Install git hooks
lefthook install

# Run the application (web target, requires Google chrome browser)
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:3000/api/v1 --web-port=5000
```

Environment variables are loaded from a `.env` file at the project root. 
Copy the provided template and fill in the required values:

```bash
cp .env.example .env
```

The `.env` file is listed in `.gitignore` and must never be committed.

---

## Git Hooks

This repository uses [lefthook](https://github.com/evilmartians/lefthook) to manage git hooks. 
lefthook has no Node.js dependency and integrates natively with the Flutter toolchain.

### Installation

```bash
# macOS
brew install lefthook

# Linux / Windows (via Go)
go install github.com/evilmartians/lefthook@latest
```

After installing lefthook, activate the hooks in your local clone:

```bash
lefthook install
```

This command must be run once after each fresh clone. It is not automatic.

### Active Hooks

| Hook         | Trigger      | Behaviour                                                                   |
|--------------|--------------|-----------------------------------------------------------------------------|
| `commit-msg` | Every commit | Validates the commit message against the Conventional Commits specification |
| `pre-push`   | Every push   | Validates the branch name against the project naming convention             |

### Commit Message Convention

All commit messages must follow the [Conventional Commits 1.0.0](https://www.conventionalcommits.org/) specification:

```
<type>(<scope>): <short description>

[optional body]

[optional footer]
```

**Allowed types:** `feat`, `fix`, `docs`, `style`, `refactor`, `test`, `chore`, `ci`, `build`, `perf`, `revert`

**Allowed scopes:** `auth`, `room`, `video-sync`, `domain`, `data`, `presentation`, `infra`

**Examples:**

```
feat(auth): implement RegisterUseCase with email uniqueness validation
fix(room): correct ownership check on room deletion
test(auth): write unit tests for LoginCubit initial state
refactor(domain): extract IAuthRepository to dedicated file
chore(infra): update Flutter SDK to 3.22
```

A commit message that does not match this format is rejected locally by the `commit-msg` hook and will also be flagged by the CI pipeline.

### Branch Naming Convention

```
<type>/<bounded-context>/<short-description-in-kebab-case>
```

**Allowed types:** `feature`, `fix`, `hotfix`, `refactor`, `test`, `docs`, `chore`, `ci`, `release`

**Examples:**

```
feature/auth/register-use-case
feature/room/create-room-page
fix/auth/token-refresh-race-condition
test/video-sync/playback-bloc-unit-tests
chore/infra/update-flutter-sdk
```

A push from a branch that does not match this pattern is rejected by the `pre-push` hook.

To bypass a hook in exceptional circumstances (not recommended):

```bash
git push --no-verify
```

---

## Running Tests

```bash
# Run all tests
flutter test

# Run tests with coverage report
flutter test --coverage

# Run tests for a specific feature
flutter test test/features/auth/

# Run a specific test file
flutter test test/features/auth/domain/use_cases/register_use_case_test.dart
```

Coverage reports are generated in `coverage/lcov.info`. To generate an HTML report:

```bash
genhtml coverage/lcov.info -o coverage/html
open coverage/html/index.html
```

Tests are written before production code following the TDD red-green-refactor cycle. Test files mirror the production code structure under `test/`.

---

## CI Pipeline

The CI pipeline runs on every push to `main` and on every pull request targeting `main`. It is defined in `.github/workflows/ci.yml`.

| Job         | Description                                  | Blocks merge |
|-------------|----------------------------------------------|--------------|
| `analyze`   | `dart format` check + `flutter analyze`      | Yes          |
| `test`      | Full test suite with coverage artefact       | Yes          |
| `build-web` | Flutter web release build (main branch only) | No           |

All jobs in the `analyze` and `test` stages must pass before a pull request is eligible for merge.
This is enforced by the branch protection ruleset on `main`.

---

## Release Process

Releases are managed automatically by [release-please](https://github.com/googleapis/release-please), configured in `.github/workflows/release-please.yml`.

**How it works:**

1. Every merge to `main` triggers the release-please workflow.
2. release-please inspects all commits since the last release and computes the next semantic version based on Conventional Commit types (`feat` → MINOR, `fix`/`refactor`/`perf` → PATCH, `BREAKING CHANGE` → MAJOR).
3. It creates or updates a **Release PR** that accumulates the changelog and version bump.
4. When you are ready to publish a release, merge the Release PR.
5. release-please creates a GitHub Release, a Git tag (`vX.Y.Z`), and updates `CHANGELOG.md` and `pubspec.yaml`.

No tag is created on a direct push to `main`. The release moment is always explicit.

---

## Contributing — Issue Creation

All work items (features, bugs, tasks) must be tracked as GitHub Issues before any code is written. This repository provides structured issue templates to ensure consistency across the backlog.

### Available Templates

| Template       | Use for                                                    |
|----------------|------------------------------------------------------------|
| **Epic**       | A high-level feature area grouping multiple related issues |
| **Feature**    | A user story or use case to implement                      |
| **Task**       | A technical sub-task of a feature                          |
| **Bug Report** | A defect or regression                                     |

To create an issue, navigate to the **Issues** tab and click **New issue**. Select the appropriate template. All mandatory fields must be completed before the issue is submitted.

### Required Fields

Every issue must include, at minimum:

- A title following the pattern `[TYPE] Short description` (pre-filled by the template)
- A bounded context (`auth`, `room`, or `video-sync`)
- Acceptance criteria or a Definition of Done
- The corresponding project fields set in the GitHub Project board: Priority, Risk Level, Sprint, Estimate, Phase, Bounded Context

Issues that do not use a template or that leave mandatory fields empty will be closed pending correction.

### Pull Requests

Every change to `main` must go through a pull request. Direct pushes to `main` are blocked by the branch protection ruleset.

PR titles must follow the same Conventional Commits format as individual commit messages. The PR description must reference the issue it closes using the keyword `Closes #<issue-number>`.

---

## Labels Reference

Labels are used to categorise issues by type and bounded context. Priority and Risk Level are managed as project-level custom fields on the GitHub Project board, not as labels.

**Type labels:**

| Label     | Usage                       |
|-----------|-----------------------------|
| `epic`    | High-level feature grouping |
| `feature` | User story or use case      |
| `task`    | Technical sub-task          |
| `bug`     | Defect or regression        |
| `test`    | Test-only issue             |
| `docs`    | Documentation               |
| `infra`   | Infrastructure or tooling   |

**Bounded context labels:**

| Label        | Usage                                 |
|--------------|---------------------------------------|
| `auth`       | Authentication bounded context        |
| `room`       | Room bounded context                  |
| `video-sync` | Video Synchronisation bounded context |