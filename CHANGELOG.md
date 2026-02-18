# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- **Switch pattern for exclusive choice routing**: New `switchOn()` method for declarative workflow branching based on selector values
  - **Value matching** with `when(value, builder)`: Execute builder when selector matches exact value
  - **Predicate matching** with `whenMatch(predicate, builder)`: Execute builder when predicate returns true
  - **Fallback handling** with `otherwise(builder)`: Execute builder when no cases match
  - **Optional fallback** with `end()`: No-op when no cases match (alternative to `otherwise()`)
  - **Execution model**:
    - Selector function evaluated exactly once when switch is reached
    - Cases checked in order until first match (short-circuit evaluation)
    - Only first matching case executes
    - Operations from matched case execute inline within a single dispatcher operation
    - Compensation handled internally within the switch operation
  - **Use cases**:
    - User type routing (admin/user/guest workflows)
    - Status-based workflows (draft/pending/approved/rejected)
    - Domain-based routing (email domain → permission levels)
    - Age-range routing with different step sequences
    - Dynamic workflow selection based on runtime state
  - **Integration**: Works seamlessly with existing guards, steps, and branches
  - **Nesting**: Switches can be nested within switch cases for complex routing
- **Comprehensive test coverage**: 95 tests total (30 switch unit tests + 12 switch integration tests + 53 existing tests)
- **Migration guide**: Complete MIGRATION.md with before/after examples and automated regex patterns for type parameter updates
- **Compensation/rollback support** (Saga pattern): Automatic best-effort cleanup when workflows fail
  - Added `compensate()` method to `RailwayStep<E, C>` with default no-op implementation
  - Compensation functions execute in reverse order (LIFO) when a step fails
  - Context captured after each step execution for accurate rollback
  - Compensation errors are suppressed to prevent cascade failures
  - Guards are excluded from compensation (read-only operations)
- **Conditional branching**: Predicate-based workflow branching with `branch()` method
  - `branch(predicate, builder)` - executes branch railway only if predicate returns true
  - Predicate evaluated once with result shared across branch operations
  - Branch steps participate in compensation chain
  - Skipped branches do not execute compensations
  - Supports nested branches with independent predicate evaluation

### Changed

- **BREAKING: Type parameter order reversed from `<C, E>` to `<E, C>`**
  - `Railway<C, E>` → `Railway<E, C>`
  - `RailwayGuard<C, E>` → `RailwayGuard<E, C>`
  - `RailwayStep<C, E>` → `RailwayStep<E, C>`
  - Rationale: Aligns with `Either<L, R>` convention where error/failure (Left) comes first
  - Makes Railway → Either conversions more intuitive
  - Migration: Reverse all type parameters in Railway, RailwayGuard, and RailwayStep declarations
  - See [MIGRATION.md](MIGRATION.md) for detailed upgrade guide with automated migration patterns
- **BREAKING**: `RailwayStep` changed from `abstract interface class` to `abstract class` to support default `compensate()` implementation
  - Migration: Change step implementations from `implements RailwayStep` to `extends RailwayStep`
  - Migration: Remove `const` constructors from step implementations
- **README documentation**: Updated all examples to use new `<E, C>` type parameter order with detailed type parameter convention section
- **Inline documentation**: Updated doc comments throughout codebase to reflect new type parameter convention
- **Example code**: Complete rewrite of example/main.dart demonstrating:
  - Basic Railway pattern with guards and steps
  - Switch pattern with user type routing (when() for value matching)
  - Switch pattern with email domain routing (whenMatch() for predicate matching)
  - Comprehensive output showing all three patterns in action

## [1.0.0] - 2026-02-17

### Added

- **Railway-oriented programming pattern for Dart**: Core abstractions for building strongly-typed, declarative workflows in application-layer orchestration.
  - `Railway<C, E>`: Immutable builder for composing guards and steps into a type-safe workflow pipeline
  - `RailwayGuard<C, E>`: Interface for read-only validation operations that return `Either<E, void>`
  - `RailwayStep<C, E>`: Interface for state mutation operations that return `Either<E, C>`
  - Automatic short-circuiting on first error with Either-based result propagation
  - Single unified error type per railway (compile-time enforced, no runtime casting)
  - Sequential asynchronous execution with deterministic operation ordering
- **Immutable builder pattern**: Each `guard()` and `step()` call returns a new Railway instance, enabling safe reuse and composition
- **Transaction-agnostic execution**: Railways remain infrastructure-only with no built-in transaction management
- **Comprehensive documentation**: README with usage examples, error mapping patterns, and context immutability patterns
- **Complete test coverage**: 30 unit and integration tests covering builder, guards, steps, and execution engine
- **Example workflow**: Demonstration of user creation workflow with validation guards and mutation steps

