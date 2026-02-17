## 1. Package Setup

- [x] 1.1 Create `packages/gradis/` directory structure
- [x] 1.2 Create `pubspec.yaml` with package metadata and `either_dart` dependency
- [x] 1.3 Create package README.md with overview and basic usage example
- [x] 1.4 Create `lib/gradis.dart` main library export file
- [x] 1.5 Create `lib/src/` directory for implementation files
- [x] 1.6 Set up `analysis_options.yaml` with strict linting rules

## 2. Core Type Definitions

- [x] 2.1 Create `lib/src/railway.dart` with `Railway<C, E>` class declaration
- [x] 2.2 Implement immutable pipeline storage using `List<Future<Either<E, C>> Function(C)>`
- [x] 2.3 Implement const constructor for `Railway` accepting optional pipeline list
- [x] 2.4 Create `lib/src/railway_guard.dart` with `RailwayGuard<C, E>` abstract interface
- [x] 2.5 Define `check(C context)` method signature returning `Future<Either<E, void>>`
- [x] 2.6 Create `lib/src/railway_step.dart` with `RailwayStep<C, E>` abstract interface
- [x] 2.7 Define `run(C context)` method signature returning `Future<Either<E, C>>`

## 3. Railway Builder Implementation

- [x] 3.1 Implement `Railway.guard(RailwayGuard<C, E> guard)` method
- [x] 3.2 Create new Railway instance with guard's check function appended to pipeline
- [x] 3.3 Implement `Railway.step(RailwayStep<C, E> step)` method
- [x] 3.4 Create new Railway instance with step's run function appended to pipeline
- [x] 3.5 Verify immutability - ensure original railway remains unchanged after guard/step calls
- [x] 3.6 Add type constraints to ensure compile-time type safety

## 4. Railway Execution Engine

- [x] 4.1 Implement `Railway.run(C initial)` method returning `Future<Either<E, C>>`
- [x] 4.2 Initialize execution with `Right<E, C>(initial)` 
- [x] 4.3 Implement sequential iteration through pipeline operations
- [x] 4.4 Use `flatMapAsync` or equivalent for automatic short-circuit behavior
- [x] 4.5 Break iteration immediately when `Left` is encountered
- [x] 4.6 Return final `Either<E, C>` result after all operations or first error
- [x] 4.7 Handle empty pipeline case (return initial context immediately)

## 5. Library Exports

- [x] 5.1 Export `Railway` class from `lib/gradis.dart`
- [x] 5.2 Export `RailwayGuard` interface from `lib/gradis.dart`
- [x] 5.3 Export `RailwayStep` interface from `lib/gradis.dart`
- [x] 5.4 Verify no internal implementation details are exposed

## 6. Unit Tests - Railway Builder

- [x] 6.1 Create `test/railway_test.dart` test file
- [x] 6.2 Test creating empty railway instance
- [x] 6.3 Test guard() returns new immutable instance
- [x] 6.4 Test step() returns new immutable instance
- [x] 6.5 Test chaining multiple guards and steps preserves order
- [x] 6.6 Test original railway unchanged after builder calls
- [x] 6.7 Test type safety with context and error types

## 7. Unit Tests - Guard Interface

- [x] 7.1 Create `test/railway_guard_test.dart` test file
- [x] 7.2 Test guard check() receives correct context
- [x] 7.3 Test successful guard returns Right(null)
- [x] 7.4 Test failed guard returns Left(error)
- [x] 7.5 Test guard cannot mutate context (verify immutability)
- [x] 7.6 Test multiple guards execute sequentially
- [x] 7.7 Test first guard failure short-circuits remaining guards

## 8. Unit Tests - Step Interface

- [x] 8.1 Create `test/railway_step_test.dart` test file
- [x] 8.2 Test step run() receives correct context
- [x] 8.3 Test successful step returns Right(updated context)
- [x] 8.4 Test failed step returns Left(error)
- [x] 8.5 Test context accumulation across multiple steps
- [x] 8.6 Test step failure short-circuits remaining steps
- [x] 8.7 Test steps can perform side effects (mock repository)

## 9. Unit Tests - Execution Engine

- [x] 9.1 Create `test/railway_execution_test.dart` test file
- [x] 9.2 Test empty railway returns initial context
- [x] 9.3 Test all operations succeed returns final context
- [x] 9.4 Test guard failure stops execution and returns error
- [x] 9.5 Test step failure stops execution and returns error
- [x] 9.6 Test sequential async operation execution
- [x] 9.7 Test Either short-circuit behavior with flatMapAsync
- [x] 9.8 Test execution is deterministic and predictable

## 10. Integration Tests

- [x] 10.1 Create `test/integration_test.dart` for end-to-end scenarios
- [x] 10.2 Test complete workflow with multiple guards and steps
- [x] 10.3 Test error mapping from guards to railway error type
- [x] 10.4 Test error mapping from steps to railway error type
- [x] 10.5 Test context accumulation in realistic workflow scenario
- [x] 10.6 Test railway execution within transaction boundary (mock)

## 11. Documentation

- [x] 11.1 Add dartdoc comments to Railway class
- [x] 11.2 Add dartdoc comments to RailwayGuard interface
- [x] 11.3 Add dartdoc comments to RailwayStep interface
- [x] 11.4 Add dartdoc comments to all public methods
- [x] 11.5 Create example/ directory with complete workflow example
- [x] 11.6 Add usage examples to README.md showing guard, step, and railway composition
- [x] 11.7 Document error mapping pattern in README.md
- [x] 11.8 Document context immutability pattern in README.md

## 12. Package Publishing Preparation

- [x] 12.1 Verify all tests pass
- [x] 12.2 Run `dart analyze` and fix all issues
- [x] 12.3 Run `dart format` on all source files
- [x] 12.4 Verify package scores 140+ on pub.dev analysis
- [x] 12.5 Add CHANGELOG.md with initial version entry
- [x] 12.6 Add LICENSE file (if not inherited from workspace)
- [x] 12.7 Review and finalize package version number
