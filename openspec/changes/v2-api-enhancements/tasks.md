## 1. Type Parameter Order Changes (Breaking)

- [x] 1.1 Update `RailwayStep<C, E>` to `RailwayStep<E, C>` in railway_step.dart
- [x] 1.2 Update `RailwayGuard<C, E>` to `RailwayGuard<E, C>` in railway_guard.dart
- [x] 1.3 Update `Railway<C, E>` to `Railway<E, C>` in railway.dart
- [x] 1.4 Update `_Operation<C, E>` to `_Operation<E, C>` in railway.dart
- [x] 1.5 Update all internal method signatures to use `<E, C>` order
- [x] 1.6 Update all `Either<E, C>` return types (verify correct order - should already be correct)

## 2. Switch Pattern Infrastructure

- [x] 2.1 Create `lib/src/railway_switch_builder.dart` file
- [x] 2.2 Define `SwitchBuilder<E, C, T>` class with type parameters
- [x] 2.3 Implement internal `_SwitchCase<E, C, T>` data structure for cases
- [x] 2.4 Add `_cases` list field to `SwitchBuilder`
- [x] 2.5 Add `_selector` function field to `SwitchBuilder`
- [x] 2.6 Add optional `_otherwise` builder field to `SwitchBuilder`

## 3. Switch Pattern API Methods

- [x] 3.1 Implement `SwitchBuilder.when(T value, builder)` for value equality matching
- [x] 3.2 Implement `SwitchBuilder.whenMatch(predicate, builder)` for predicate-based matching
- [x] 3.3 Implement `SwitchBuilder.otherwise(builder)` returning Railway
- [x] 3.4 Implement `SwitchBuilder.end()` returning Railway without fallback
- [x] 3.5 Add `Railway.switchOn<T>(selector)` method returning SwitchBuilder
- [x] 3.6 Export SwitchBuilder in lib/gradis.dart

## 4. Switch Pattern Execution Logic

- [x] 4.1 Create `_SwitchOperation<E, C>` class extending/similar to `_Operation`
- [x] 4.2 Implement selector evaluation (once, with error handling)
- [x] 4.3 Implement case iteration with short-circuit on first match
- [x] 4.4 Implement value equality comparison for `when()` cases
- [x] 4.5 Implement predicate evaluation for `whenMatch()` cases
- [x] 4.6 Implement fallback execution if no cases match
- [x] 4.7 Implement passthrough behavior when no match and no otherwise
- [x] 4.8 Merge matched case operations into parent Railway's operation list
- [x] 4.9 Handle selector exceptions (catch and wrap in Left)

## 5. Update Unit Tests - Type Parameters

- [x] 5.1 Update railway_test.dart: Change all `Railway<Context, Error>` to `Railway<Error, Context>`
- [x] 5.2 Update railway_step_test.dart: Change all `RailwayStep<Context, Error>` to `RailwayStep<Error, Context>`
- [x] 5.3 Update railway_guard_test.dart: Change all `RailwayGuard<Context, Error>` to `RailwayGuard<Error, Context>`
- [x] 5.4 Update railway_branch_test.dart: Update type parameters
- [x] 5.5 Update railway_compensation_test.dart: Update type parameters
- [x] 5.6 Verify all unit tests pass after type parameter changes

## 6. Update Integration Tests - Type Parameters

- [x] 6.1 Update railway_workflow_contract_test.dart: Update type parameters
- [x] 6.2 Update railway_execution_behavior_test.dart: Update type parameters
- [x] 6.3 Update railway_compensation_branch_test.dart: Update type parameters
- [x] 6.4 Verify all integration tests pass after type parameter changes

## 7. Switch Pattern Integration Tests

- [x] 7.1 Create test/integration/railway_switch_test.dart file
- [x] 7.2 Test: Switch builder creation from railway
- [x] 7.3 Test: Value equality matching with when()
- [x] 7.4 Test: Predicate matching with whenMatch()
- [x] 7.5 Test: Range matching with whenMatch()
- [x] 7.6 Test: Otherwise fallback execution
- [x] 7.7 Test: End without fallback (passthrough)
- [x] 7.8 Test: Short-circuit on first match
- [x] 7.9 Test: Selector evaluated exactly once
- [x] 7.10 Test: Multiple cases in order
- [x] 7.11 Test: Empty switch (no cases)
- [x] 7.12 Test: Switch returns to railway chain
- [x] 7.13 Test: Type safety (compile-time verification)

## 8. Switch Pattern Integration Tests

- [x] 8.1 Create test/integration/railway_switch_workflow_test.dart file
- [x] 8.2 Test: User type routing workflow (child/adult/senior)
- [x] 8.3 Test: Status-based workflow (draft/pending/approved/rejected)
- [x] 8.4 Test: Age-range routing with multiple steps per case
- [x] 8.5 Test: Switch cases participate in main compensation stack
- [x] 8.6 Test: Failed step in switch case triggers global compensation
- [x] 8.7 Test: Nested switch patterns
- [x] 8.8 Test: Switch combined with branch and guards
- [x] 8.9 Test: Selector error handling (exception in selector)
- [x] 8.10 Test: Complex workflow with multiple switches

## 9. Update Examples

- [x] 9.1 Update example/main.dart: Change type parameters to `<E, C>`
- [x] 9.2 Add switch pattern example to example/main.dart
- [x] 9.3 Create example demonstrating user type routing
- [x] 9.4 Create example demonstrating status workflow
- [x] 9.5 Add comments explaining type parameter order

## 10. Documentation Updates

- [x] 10.1 Update README.md: Explain type parameter order `<E, C>`
- [x] 10.2 Update README.md: Add switch pattern documentation section
- [x] 10.3 Update README.md: Add switch API examples (when, whenMatch, otherwise)
- [x] 10.4 Update inline doc comments in railway.dart for `<E, C>`
- [x] 10.5 Update inline doc comments in railway_step.dart for `<E, C>`
- [x] 10.6 Update inline doc comments in railway_guard.dart for `<E, C>`
- [x] 10.7 Add comprehensive doc comments to SwitchBuilder class
- [x] 10.8 Add doc comments to switchOn() method explaining usage

## 11. Migration Guide and Changelog

- [x] 11.1 Create MIGRATION.md with v2 upgrade guide
- [x] 11.2 Document regex patterns for type parameter migration
- [x] 11.3 Add before/after code examples in migration guide
- [x] 11.4 Update CHANGELOG.md with breaking changes section
- [x] 11.5 Update CHANGELOG.md with new switch pattern feature
- [x] 11.6 Document rationale for type parameter order change
- [x] 11.7 Add switch pattern use cases and benefits to changelog

## 12. Edge Cases and Error Handling

- [x] 12.1 Test: Selector returns null
- [x] 12.2 Test: Selector throws synchronous exception
- [x] 12.3 Test: Selector throws asynchronous exception
- [x] 12.4 Test: Predicate throws exception
- [x] 12.5 Test: Builder function throws exception
- [x] 12.6 Test: Empty railway returned from case builder
- [x] 12.7 Handle edge case: switch after failed operation
- [x] 12.8 Validate behavior with nullable types

## 13. Performance and Optimization

- [x] 13.1 Verify selector is not called redundantly
- [x] 13.2 Verify predicates stop evaluating after first match
- [x] 13.3 Profile switch execution vs chained branches
- [x] 13.4 Optimize case list iteration for common cases
- [x] 13.5 Consider lazy case evaluation if needed

## 14. Final Validation and Release Prep

- [x] 14.1 Run all tests: `dart test`
- [x] 14.2 Run static analysis: `dart analyze`
- [x] 14.3 Run formatter: `dart format .`
- [x] 14.5 Verify all public API has documentation (>95% coverage)
- [x] 14.6 Review breaking changes list completeness
- [x] 14.7 Final review of migration guide clarity
