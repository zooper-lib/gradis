## 1. Update RailwayStep Interface

- [x] 1.1 Add `compensate` method to RailwayStep interface with default empty implementation
- [x] 1.2 Update RailwayStep documentation to explain compensation behavior and best practices
- [x] 1.3 Verify existing test step implementations compile with new interface

## 2. Create Internal Operation Structure

- [x] 2.1 Create private `_Operation<C, E>` class to encapsulate operation + compensation pairs
- [x] 2.2 Add `execute` field of type `Future<Either<E, C>> Function(C)` to `_Operation`
- [x] 2.3 Add optional `compensate` field of type `Future<void> Function(C)?` to `_Operation`
- [x] 2.4 Add `_Operation` constructor accepting execute function and optional compensate function
- [x] 2.5 Add `capturedContext` field to track context at execution time for compensation

## 3. Refactor Railway Internal Structure

- [x] 3.1 Change `_pipeline` field from `List<Function>` to `List<_Operation<C, E>>`
- [x] 3.2 Update Railway constructor to accept `List<_Operation<C, E>>`
- [x] 3.3 Update `guard` method to create `_Operation` with no compensation
- [x] 3.4 Update `step` method to create `_Operation` with step's compensate function
- [x] 3.5 Verify immutable builder pattern still works correctly

## 4. Implement Compensation Execution Logic

- [x] 4.1 Create runtime compensation stack structure to track executed operations with their contexts
- [x] 4.2 Modify Railway.run() to build compensation stack during forward execution
- [x] 4.3 Capture context for each executed step in the compensation stack
- [x] 4.4 Implement compensation execution in reverse order when operation fails
- [x] 4.5 Wrap each compensation call in try-catch to suppress compensation errors
- [x] 4.6 Ensure original error is preserved and returned even if compensations fail
- [x] 4.7 Ensure compensations only execute for operations that completed successfully

## 5. Implement Branch Method

- [x] 5.1 Add `branch` method to Railway class accepting predicate and builder functions
- [x] 5.2 Implement predicate evaluation at execution time with current context
- [x] 5.3 Create branch sub-pipeline using builder function when predicate is true
- [x] 5.4 Execute branch sub-pipeline operations when predicate is true
- [x] 5.5 Skip branch and pass context through when predicate is false
- [x] 5.6 Integrate branch operations into main compensation stack
- [x] 5.7 Ensure branch failures propagate correctly to main pipeline
- [x] 5.8 Return new Railway instance maintaining immutable builder pattern
- [x] 5.9 Add documentation for branch method with usage examples

## 6. Test Compensation Behavior

- [x] 6.1 Write test for step with compensation that executes on failure
- [x] 6.2 Write test for multiple steps with compensations executing in reverse order
- [x] 6.3 Write test for early failure preventing later step compensations
- [x] 6.4 Write test for successful pipeline not executing compensations
- [x] 6.5 Write test for compensation receiving correct captured context
- [x] 6.6 Write test for compensation error being suppressed and original error returned
- [x] 6.7 Write test for multiple compensation failures not stopping cleanup
- [x] 6.8 Write test for guards excluded from compensation
- [x] 6.9 Write test for guard failure before steps (no compensations)

## 7. Test Branch Behavior

- [x] 7.1 Write test for branch with true predicate executing sub-pipeline
- [x] 7.2 Write test for branch with false predicate skipping sub-pipeline
- [x] 7.3 Write test for branch step compensations executing on later failure
- [x] 7.4 Write test for skipped branch having no compensations
- [x] 7.5 Write test for branch step failure propagating to main pipeline
- [x] 7.6 Write test for branch guard failure propagating to main pipeline
- [x] 7.7 Write test for nested branches executing correctly
- [x] 7.8 Write test for nested branch compensations in correct reverse order
- [x] 7.9 Write test for branch maintaining immutable builder pattern

## 8. Integration Tests

- [x] 8.1 Write integration test for complex workflow with mixed guards, steps, and branches
- [x] 8.2 Write integration test for nested branches with compensations
- [x] 8.3 Write integration test for compensation stack with branches interleaved
- [x] 8.4 Verify all existing integration tests still pass

## 9. Update Documentation

- [x] 9.1 Update README with compensation feature explanation and examples
- [x] 9.2 Update README with branch feature explanation and examples
- [x] 9.3 Document compensation best practices (idempotency, best-effort semantics)
- [x] 9.4 Add example showing rollback scenario with compensation
- [x] 9.5 Add example showing conditional workflow with branching
- [x] 9.6 Update CHANGELOG with breaking change notice for RailwayStep

## 10. Migration Support

- [x] 10.1 Create migration guide documenting RailwayStep interface change
- [x] 10.2 Provide example of adding compensate method to existing steps
- [x] 10.3 Document when to use compensation vs when it's not needed
- [x] 10.4 Add note about default implementation allowing gradual migration
