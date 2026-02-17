## ADDED Requirements

### Requirement: RailwayStep interface definition

The system SHALL provide a `RailwayStep<C, E>` interface for state mutation operations.

#### Scenario: Step interface contract
- **WHEN** implementing a `RailwayStep<C, E>`
- **THEN** the implementation must provide a `run(C context)` method
- **THEN** the method must return `Future<Either<E, C>>`

#### Scenario: Step receives and returns context
- **WHEN** a step's `run()` method is invoked
- **THEN** the step receives the current context
- **THEN** the step returns an updated context on success

### Requirement: Step mutation semantics

The system SHALL ensure steps perform state mutation and return updated context.

#### Scenario: Successful state mutation
- **WHEN** a step executes successfully
- **THEN** the step returns `Right(updated context)`
- **THEN** the updated context flows to the next operation

#### Scenario: Failed state mutation
- **WHEN** a step encounters an error during mutation
- **THEN** the step returns `Left(error)` with the appropriate error type
- **THEN** the railway short-circuits and stops execution

#### Scenario: Context immutability pattern
- **WHEN** a step needs to update the context
- **THEN** the step must create a new context instance using `copyWith` or similar pattern
- **THEN** the step must not mutate the input context

### Requirement: Step error mapping responsibility

The system SHALL require steps to map internal errors to the railway error type.

#### Scenario: Mapping repository errors to railway errors
- **WHEN** a step calls a repository that returns a failure
- **THEN** the step must map the repository error to the railway error type `E`
- **THEN** the railway receives only errors of type `E`

#### Scenario: Mapping use case errors to railway errors
- **WHEN** a step wraps a use case that can fail
- **THEN** the step must map the use case error to the railway error type `E`
- **THEN** error context is preserved for UX purposes

### Requirement: Step composition support

The system SHALL allow multiple steps to be added to a railway.

#### Scenario: Sequential step execution
- **WHEN** multiple steps are added to a railway
- **THEN** steps execute in the order they were added
- **THEN** each step receives the context returned by the previous step

#### Scenario: Context accumulation across steps
- **WHEN** multiple steps execute sequentially
- **THEN** each step can add data to the context
- **THEN** later steps have access to all accumulated data from previous steps

#### Scenario: First step failure short-circuits
- **WHEN** a step fails
- **THEN** subsequent steps are not executed
- **THEN** the railway returns the failing step's error

### Requirement: Step can perform side effects

The system SHALL allow steps to perform side effects such as repository writes.

#### Scenario: Repository write in step
- **WHEN** a step needs to persist data
- **THEN** the step can call repository methods
- **THEN** the step returns updated context on success or error on failure

#### Scenario: Multiple side effects in step
- **WHEN** a step performs multiple operations
- **THEN** the step coordinates all operations
- **THEN** the step handles partial failures by returning appropriate errors
