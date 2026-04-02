## Linked Issue

Closes #

<!--
  Replace the issue number above.
  "Closes #N" automatically closes the issue and transitions it to Done
  in the GitHub Project board on merge.
  Use "Refs #N" if this PR addresses the issue partially.
-->

---

## Type of Change

<!-- Mark the relevant option with an [x]. -->

- [ ] `feat` — new functionality
- [ ] `fix` — bug correction
- [ ] `refactor` — code restructuring without behaviour change
- [ ] `test` — adding or correcting tests only
- [ ] `docs` — documentation only
- [ ] `chore` — tooling, dependencies, build scripts
- [ ] `ci` — CI/CD pipeline changes
- [ ] `perf` — performance improvement

---

## Summary

<!--
  Describe what this PR does and why.
  Focus on the functional intent, not the implementation details.
  One to three sentences is sufficient for most PRs.
-->

---

## Changes

<!--
  List the significant technical changes introduced.
  Group by architectural layer where relevant (Domain / Data / Presentation).
-->

- 
- 

---

## Test Coverage

<!--
  List the tests written or updated in this PR.
  For TDD PRs, indicate which use cases or BLoC states are now covered.
-->

- [ ] Unit tests written / updated for: 
- [ ] Widget tests written / updated for: 
- [ ] All existing tests pass (`flutter test`)

---

## Screenshots

<!--
  Required for any change that affects the UI (Presentation layer).
  Delete this section if the PR contains no UI changes.
-->

| Before | After |
|---|---|
| | |

---

## Self-Review Checklist

<!--
  Complete this checklist before marking the PR as ready for merge.
  Every unchecked item must be accompanied by a justification comment.
-->

- [ ] The PR title conforms to the Conventional Commits format: `<type>(<scope>): <description>`
- [ ] The branch name conforms to the naming convention: `<type>/<bounded-context>/<description>`
- [ ] The code follows the Clean Architecture layer boundaries (no cross-layer imports)
- [ ] No business logic is present in the Presentation layer (BLoC / Cubit only delegates to use cases)
- [ ] All new public classes and methods have documentation comments (`///`)
- [ ] No hardcoded strings, credentials, or environment-specific values are present
- [ ] `flutter analyze` passes with no warnings or infos
- [ ] `dart format` has been applied
- [ ] Coverage for the changed code is adequate
- [ ] The CHANGELOG and `pubspec.yaml` version are **not** manually edited (managed by `release-please`)
