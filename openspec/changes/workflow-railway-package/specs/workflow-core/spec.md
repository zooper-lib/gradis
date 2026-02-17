## ADDED Requirements

### Requirement: Railway builder pattern

The system SHALL provide a `Railway<C, E>` class that uses an immutable builder pattern for composing guards and steps.

#### Scenario: Creating an empty railway
- **WHEN** a new `Railway<C, E>()` is instantiated
- **THEN** the railway contains zero operations in its pipeline

#### Scenario: Adding a guard returns new railway instance
- **WHEN** `guard()` is called on a railway instance
- **THEN** a new `Railway` instance is returned with the guard added to the pipeline
- **THEN** the original railway instance remains unchanged

#### Scenario: Adding a step returns new railway instance
- **WHEN** `step()` is called on a railway instance
- **THEN** a new `Railway` instance is returned with the step added to the pipeline
- **THEN** the original railway instance remains unchanged

#### Scenario: Chaining guards and steps
- **WHEN** multiple `guard()` and `step()` calls are chained
- **THEN** each call returns a new immutable railway instance
- **THEN** operations are executed in the order they were added

### Requirement: Strongly-typed context propagation

The system SHALL propagate a strongly-typed context `C` through the railway pipeline.

#### Scenario: Initial context is passed to first operation
- **WHEN** `run()` is called with an initial context
- **THEN** the first operation receives the initial context

#### Scenario: Context flows between operations
- **WHEN** a step returns an updated context
- **THEN** the next operation receives the updated context

#### Scenario: Context type is enforced at compile time
- **WHEN** defining a railway with type parameters `Railway<C, E>`
- **THEN** all operations must accept and return the same context type `C`
- **THEN** the compiler enforces type safety without runtime casting

### Requirement: Single error type per railway

The system SHALL enforce a single unified error type `E` for all operations in a railway.

#### Scenario: All operations share the same error type
- **WHEN** defining a railway with type parameters `Railway<C, E>`
- **THEN** all guards must return `Either<E, void>`
- **THEN** all steps must return `Either<E, C>`
- **THEN** the railway execution must return `Either<E, C>`

#### Scenario: Error type is enforced at compile time
- **WHEN** attempting to add a guard or step with a different error type
- **THEN** the compiler prevents the operation
- **THEN** no runtime type checking or casting is required

### Requirement: Railway execution interface

The system SHALL provide a `run()` method that executes the pipeline with an initial context.

#### Scenario: Executing an empty railway
- **WHEN** `run()` is called on an empty railway
- **THEN** the method returns `Right(initial context)` immediately

#### Scenario: Successful railway execution
- **WHEN** `run()` is called and all operations succeed
- **THEN** the method returns `Right(final context)` with the accumulated results

#### Scenario: Failed railway execution
- **WHEN** `run()` is called and any operation fails
- **THEN** the method returns `Left(error)` from the first failing operation
- **THEN** subsequent operations are not executed

### Requirement: Asynchronous operation support

The system SHALL support asynchronous guards and steps.

#### Scenario: Running async operations
- **WHEN** guards or steps return `Future<Either<E, ...>>`
- **THEN** the railway execution awaits each operation sequentially
- **THEN** the `run()` method returns `Future<Either<E, C>>`

#### Scenario: Async operation ordering
- **WHEN** multiple async operations are in the pipeline
- **THEN** they execute in sequence, not in parallel
- **THEN** each operation completes before the next begins
