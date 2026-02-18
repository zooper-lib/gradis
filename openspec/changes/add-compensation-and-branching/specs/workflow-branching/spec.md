## ADDED Requirements

### Requirement: Railway supports conditional branching

The `Railway` class SHALL provide a `branch` method that enables conditional execution of sub-pipelines based on a predicate function evaluated against the current context.

#### Scenario: Branch method signature

- **WHEN** calling the `branch` method on a Railway instance
- **THEN** the method SHALL accept a predicate function of type `bool Function(C)`
- **THEN** the method SHALL accept a builder function of type `Railway<C, E> Function(Railway<C, E>)`
- **THEN** the method SHALL return a new `Railway<C, E>` instance

#### Scenario: Immutable builder pattern

- **WHEN** the `branch` method is called
- **THEN** a new Railway instance SHALL be returned
- **THEN** the original Railway instance SHALL remain unchanged

### Requirement: Branch predicate evaluates runtime context

The branch predicate function SHALL be evaluated with the current context at the point the branch is reached during pipeline execution. The predicate result determines whether the branch sub-pipeline executes.

#### Scenario: Predicate evaluated at execution time

- **WHEN** a railway pipeline reaches a branch operation
- **THEN** the predicate function SHALL be called with the current context
- **THEN** the predicate SHALL return a boolean value indicating whether to execute the branch

#### Scenario: Predicate true executes branch

- **WHEN** a branch predicate evaluates to true
- **THEN** the branch sub-pipeline SHALL execute
- **THEN** the branch sub-pipeline SHALL receive the current context
- **THEN** the branch result SHALL become the new current context

#### Scenario: Predicate false skips branch

- **WHEN** a branch predicate evaluates to false
- **THEN** the branch sub-pipeline SHALL NOT execute
- **THEN** the current context SHALL pass through unchanged
- **THEN** execution SHALL continue with the next operation after the branch

### Requirement: Branch builder creates sub-pipeline

The branch builder function SHALL receive a fresh Railway instance and SHALL return a Railway with the desired branch operations. This allows composing branch logic using the same builder pattern as the main pipeline.

#### Scenario: Builder receives empty railway

- **WHEN** the branch builder function is invoked
- **THEN** it SHALL receive a new Railway instance with no operations
- **THEN** the builder can chain guards and steps onto this instance
- **THEN** the builder SHALL return the configured Railway

#### Scenario: Builder composes branch operations

- **WHEN** the builder adds steps and guards to the Railway
- **THEN** those operations SHALL only execute if the branch predicate is true
- **THEN** the operations SHALL execute in the order they were added to the builder

### Requirement: Branch integrates with compensation stack

When a branch executes, any steps within the branch sub-pipeline SHALL participate in the compensation mechanism. If a later operation fails, branch step compensations SHALL execute in the correct reverse order relative to the entire pipeline.

#### Scenario: Branch step compensations execute on failure

- **WHEN** a branch sub-pipeline contains steps with compensation
- **WHEN** the branch executes (predicate is true)
- **WHEN** a later operation (inside or outside the branch) fails
- **THEN** compensations for branch steps SHALL execute in reverse order
- **THEN** branch compensations SHALL be interleaved correctly with main pipeline compensations

#### Scenario: Skipped branch has no compensations

- **WHEN** a branch predicate evaluates to false
- **WHEN** a later operation fails and triggers compensations
- **THEN** no compensations from the skipped branch SHALL execute
- **THEN** only executed step compensations SHALL run

### Requirement: Branch failure propagates to main pipeline

If any operation within a branch sub-pipeline fails, the failure SHALL propagate to the main pipeline, triggering the standard error handling and compensation behavior.

#### Scenario: Branch step failure stops pipeline

- **WHEN** a step inside a branch sub-pipeline fails
- **THEN** the branch execution SHALL stop immediately
- **THEN** compensations SHALL execute for all previously successful operations
- **THEN** the main pipeline SHALL return the error from the branch step

#### Scenario: Branch guard failure stops pipeline

- **WHEN** a guard inside a branch sub-pipeline fails
- **THEN** the branch execution SHALL stop immediately
- **THEN** compensations SHALL execute (excluding the guard)
- **THEN** the main pipeline SHALL return the error from the branch guard

### Requirement: Branches execute sequentially

Branch sub-pipelines SHALL execute sequentially in the order they are defined in the main pipeline. There SHALL be no parallel execution of branches.

#### Scenario: Single branch execution path

- **WHEN** a railway contains multiple branch operations
- **WHEN** multiple predicates evaluate to true
- **THEN** each branch SHALL execute completely before the next branch is evaluated
- **THEN** branches SHALL NOT execute in parallel

### Requirement: Nested branches are supported

A branch sub-pipeline MAY contain additional branch operations, creating nested conditional execution paths. Nested branches SHALL follow the same predicate evaluation and compensation rules.

#### Scenario: Branch contains another branch

- **WHEN** a branch builder creates a sub-pipeline with its own branch
- **THEN** the nested branch SHALL be valid
- **THEN** the nested branch predicate SHALL evaluate when the outer branch executes
- **THEN** compensation order SHALL correctly reflect the nested structure

#### Scenario: Nested branch compensation order

- **WHEN** nested branches execute and contain steps
- **WHEN** a later operation fails
- **THEN** compensations SHALL execute in reverse order of execution
- **THEN** deeply nested step compensations SHALL execute before outer step compensations
