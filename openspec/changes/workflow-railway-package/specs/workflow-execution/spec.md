## ADDED Requirements

### Requirement: Short-circuit execution on first failure

The system SHALL stop executing operations immediately when the first error occurs.

#### Scenario: Guard failure stops execution
- **WHEN** a guard returns `Left(error)`
- **THEN** the railway stops execution immediately
- **THEN** subsequent guards and steps are not executed
- **THEN** the railway returns the error

#### Scenario: Step failure stops execution
- **WHEN** a step returns `Left(error)`
- **THEN** the railway stops execution immediately
- **THEN** subsequent steps are not executed
- **THEN** the railway returns the error

#### Scenario: Success continues execution
- **WHEN** a guard or step returns `Right(...)`
- **THEN** the railway continues to the next operation
- **THEN** the pipeline executes until completion or first error

### Requirement: Either-based result propagation

The system SHALL use Either monad for propagating success and failure through the pipeline.

#### Scenario: Right propagation
- **WHEN** an operation returns `Right(value)`
- **THEN** the value is passed to the next operation
- **THEN** execution continues through the pipeline

#### Scenario: Left propagation
- **WHEN** an operation returns `Left(error)`
- **THEN** the error is returned as the final result
- **THEN** the pipeline short-circuits

#### Scenario: flatMapAsync for composition
- **WHEN** composing operations in the pipeline
- **THEN** the railway uses `flatMapAsync` or equivalent for sequential composition
- **THEN** short-circuiting happens automatically without explicit conditionals

### Requirement: Sequential asynchronous execution

The system SHALL execute all operations sequentially, waiting for each to complete.

#### Scenario: Operations execute in order
- **WHEN** the railway contains multiple async operations
- **THEN** operations execute one at a time in the order added
- **THEN** each operation completes before the next begins

#### Scenario: No parallel execution
- **WHEN** running a railway with multiple operations
- **THEN** operations must not run in parallel
- **THEN** execution order is deterministic and predictable

### Requirement: Final result handling

The system SHALL return the final result as Either containing error or final context.

#### Scenario: All operations succeed
- **WHEN** all guards and steps return success
- **THEN** the railway returns `Right(final context)`
- **THEN** the final context contains all accumulated data

#### Scenario: Any operation fails
- **WHEN** any guard or step returns an error
- **THEN** the railway returns `Left(error)` from the first failure
- **THEN** the error type matches the railway's error type `E`

#### Scenario: Empty railway execution
- **WHEN** running a railway with no operations
- **THEN** the railway returns `Right(initial context)`
- **THEN** no transformations are applied to the context

### Requirement: Type-safe pipeline execution

The system SHALL execute the pipeline without runtime type checking or casting.

#### Scenario: Compile-time type safety
- **WHEN** building and executing a railway
- **THEN** all type constraints are enforced at compile time
- **THEN** no runtime type checks or casts are required

#### Scenario: Context type consistency
- **WHEN** a railway executes
- **THEN** the context type `C` remains consistent throughout
- **THEN** the type system prevents type mismatches

#### Scenario: Error type consistency
- **WHEN** a railway executes
- **THEN** the error type `E` remains consistent throughout
- **THEN** all errors are of the declared type `E`

### Requirement: No transaction management

The system SHALL not perform transaction management within the railway execution.

#### Scenario: Railway is transaction-agnostic
- **WHEN** a railway executes
- **THEN** the railway does not begin, commit, or rollback transactions
- **THEN** transaction boundaries are the caller's responsibility

#### Scenario: Steps can run within transactions
- **WHEN** a railway is executed within a transaction
- **THEN** steps perform their operations within that transaction context
- **THEN** the railway does not interfere with transaction management
