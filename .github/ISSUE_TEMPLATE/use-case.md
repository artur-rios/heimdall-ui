---
name: Use case
about: A use case from the Use Case Specification Document
title: "UI-00: Use case name"
labels: use-case
---

## Use case

See the [Use Case Specification Document](../../docs/requirements/Use%20Case%20Specification%20Document.md).

**Traces to:** the API use case(s) this consumes.

## Scope

What the screen or flow must do, in terms of the main flow and each alternative flow.

## Definition of Done

- [ ] Main flow and every alternative flow implemented.
- [ ] Unit tests cover the controller and any mapping or guard logic.
- [ ] Widget tests cover the screen at every breakpoint whose layout differs.
- [ ] Verified in both the light and the dark theme.
- [ ] No presentation file imports `package:heimdall_api_client`.
- [ ] `dart format --set-exit-if-changed .`, `flutter analyze`, and `flutter test` all pass.
- [ ] Pull request merged, branch deleted, and the README tracker ticked.
