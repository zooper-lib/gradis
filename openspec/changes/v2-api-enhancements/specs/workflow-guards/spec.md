## MODIFIED Requirements

### Requirement: RailwayGuard interface definition

The system SHALL provide a `RailwayGuard<E, C>` interface for validation operations.

#### Scenario: Guard interface contract
- **WHEN** implementing a `RailwayGuard<E, C>`
- **THEN** the implementation must provide a `check(C context)` method
- **THEN** the method must return `Future<Either<E, void>>`

#### Scenario: Guard receives context immutably
- **WHEN** a guard's `check()` method is invoked
- **THEN** the guard receives the current context
- **THEN** the guard cannot modify the context

### Requirement: Guard validation semantics

The system SHALL ensure guards perform read-only validation without context mutation.

#### Scenario: Successful validation
- **WHEN** a guard validates successfully
- **THEN** the guard returns `Right(null)` or `Right(unit)`
- **THEN** the context is passed unchanged to the next operation

#### Scenario: Failed validation
- **WHEN** a guard detects a validation error
- **THEN** the guard returns `Left(error)` with the appropriate error type
- **THEN** the railway short-circuits and stops execution

#### Scenario: Guard does not mutate context
- **WHEN** a guard performs validation
- **THEN** the guard must not modify the context object
- **THEN** the same context instance flows to the next operation

### Requirement: Guard error mapping responsibility

The system SHALL require guards to map internal errors to the railway error type.

#### Scenario: Mapping use case errors to railway errors
- **WHEN** a guard calls an internal use case that returns a domain error
- **THEN** the guard must map the domain error to the railway error type `E`
- **THEN** the railway receives only errors of type `E`

#### Scenario: Error mapping preserves UX context
- **WHEN** mapping internal errors to railway errors
- **THEN** the guard should preserve user-facing error information
- **THEN** the mapped error contains appropriate UX messaging

### Requirement: Guard composition support

The system SHALL allow multiple guards to be added to a railway.

#### Scenario: Sequential guard execution
- **WHEN** multiple guards are added to a railway
- **THEN** guards execute in the order they were added
- **THEN** each guard receives the same unmodified context

#### Scenario: First guard failure short-circuits
- **WHEN** the first guard fails
- **THEN** subsequent guards are not executed
- **THEN** the railway returns the first guard's error
