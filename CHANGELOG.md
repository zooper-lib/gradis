# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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

