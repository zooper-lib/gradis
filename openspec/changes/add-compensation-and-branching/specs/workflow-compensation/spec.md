## ADDED Requirements

### Requirement: Steps can define compensation operations

The `RailwayStep` interface SHALL include a `compensate` method that allows steps to define cleanup or undo operations. The method SHALL accept the context that was current when the step executed and SHALL return a `Future<void>`.

#### Scenario: Step implements compensation

- **WHEN** a step class implements the `RailwayStep` interface
- **THEN** the step MUST provide a `compensate` method signature
- **THEN** the method SHALL accept a context parameter of type `C`
- **THEN** the method SHALL return `Future<void>`

#### Scenario: Step with no compensation needed

- **WHEN** a step does not require cleanup or undo operations
- **THEN** the step MAY provide an empty compensation implementation using the default `async {}`
- **THEN** the step SHALL still be valid and compilable

### Requirement: Railway executes compensations on failure

The `Railway` SHALL execute compensation operations in reverse order (LIFO) when any operation in the pipeline fails. Compensations SHALL only execute for steps that successfully completed before the failure.

#### Scenario: Failure triggers compensations

- **WHEN** a railway pipeline contains multiple steps
- **WHEN** a step fails after other steps have succeeded
- **THEN** the railway SHALL execute compensation operations for all previously succeeded steps
- **THEN** compensations SHALL execute in reverse order of step execution

#### Scenario: Early failure prevents later compensations

- **WHEN** a step fails early in the pipeline
- **WHEN** later steps in the pipeline were never executed
- **THEN** the railway SHALL NOT execute compensation for steps that never ran
- **THEN** only compensations for executed steps SHALL run

#### Scenario: Success skips compensations

- **WHEN** all steps in a railway pipeline succeed
- **THEN** the railway SHALL NOT execute any compensation operations
- **THEN** the railway SHALL return the final successful context

### Requirement: Compensation captures execution context

Each compensation operation SHALL receive the context that was current when the corresponding step executed. This allows compensations to accurately undo or clean up based on the state at execution time.

#### Scenario: Compensation receives step context

- **WHEN** a step executes successfully with context state C1
- **WHEN** a later step fails with context state C2
- **THEN** the first step's compensation SHALL receive context C1, not C2
- **THEN** the compensation can use C1 to perform accurate cleanup

### Requirement: Compensation errors do not mask original error

When compensations execute due to a pipeline failure, any errors during compensation SHALL be handled silently. The original error that triggered compensations SHALL be returned to the caller.

#### Scenario: Compensation failure is suppressed

- **WHEN** a step fails and triggers compensation execution
- **WHEN** a compensation operation throws an error or fails
- **THEN** the railway SHALL continue executing remaining compensations
- **THEN** the railway SHALL return the original error, not the compensation error

#### Scenario: Multiple compensation failures

- **WHEN** multiple compensations fail during cleanup
- **THEN** all compensations SHALL still attempt to execute
- **THEN** the original pipeline error SHALL be returned
- **THEN** compensation errors MAY be logged but SHALL NOT be returned to caller

### Requirement: Guards are excluded from compensation

The `RailwayGuard` operations SHALL NOT participate in the compensation mechanism. Only `RailwayStep` operations SHALL be eligible for compensation.

#### Scenario: Guards have no compensation

- **WHEN** a railway contains guards and steps
- **WHEN** a later operation fails and triggers compensation
- **THEN** only step compensations SHALL execute
- **THEN** guards SHALL NOT be included in the compensation stack

#### Scenario: Guard failure prevents downstream execution

- **WHEN** a guard fails before any steps execute
- **THEN** no compensations SHALL execute
- **THEN** the guard's error SHALL be returned immediately

### Requirement: Compensation is best-effort cleanup

The compensation mechanism SHALL provide best-effort cleanup semantics, not transactional guarantees. Users SHALL be responsible for designing idempotent compensation operations where state consistency is critical.

#### Scenario: Compensation does not guarantee consistency

- **WHEN** a step modifies external state (database, API call, file system)
- **WHEN** the step fails and compensation executes
- **THEN** the system SHALL attempt compensation but SHALL NOT guarantee atomicity
- **THEN** users MUST design compensations to handle partial failure scenarios

#### Scenario: Idempotent compensation design

- **WHEN** a compensation operation may execute multiple times (due to retry logic)
- **THEN** the compensation SHOULD be designed to be idempotent
- **THEN** repeated compensation execution SHALL NOT cause incorrect state
