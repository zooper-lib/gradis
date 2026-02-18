## ADDED Requirements

### Requirement: Switch builder pattern

The system SHALL provide a `switchOn()` method on `Railway<E, C>` that accepts a selector function and returns a `SwitchBuilder<E, C, T>` for declarative exclusive choice routing.

#### Scenario: Creating a switch from railway
- **WHEN** `switchOn(selector)` is called on a railway instance
- **THEN** a `SwitchBuilder<E, C, T>` instance is returned
- **THEN** the builder captures the selector function for later evaluation

#### Scenario: Switch returns to railway chain
- **WHEN** a switch builder is terminated with `otherwise()` or `end()`
- **THEN** a `Railway<E, C>` instance is returned
- **THEN** the railway chain can continue with additional operations

### Requirement: Value-based case matching

The system SHALL provide a `when()` method on `SwitchBuilder` that matches selector output by value equality.

#### Scenario: Adding value-based case
- **WHEN** `when(value, builder)` is called on a switch builder
- **THEN** the case is added to the internal case list
- **THEN** the same switch builder instance is returned for fluent chaining

#### Scenario: Value equality matching at runtime
- **WHEN** the switch executes and selector output equals a case value
- **THEN** that case's builder function is executed
- **THEN** subsequent cases are not evaluated

#### Scenario: Multiple value cases checked in order
- **WHEN** multiple `when()` cases are defined
- **THEN** cases are evaluated in the order they were added
- **THEN** only the first matching case executes

### Requirement: Predicate-based case matching

The system SHALL provide a `whenMatch()` method on `SwitchBuilder` that matches using a predicate function.

#### Scenario: Adding predicate-based case
- **WHEN** `whenMatch(predicate, builder)` is called on a switch builder
- **THEN** the case is added to the internal case list with the predicate
- **THEN** the same switch builder instance is returned for fluent chaining

#### Scenario: Predicate evaluation at runtime
- **WHEN** the switch executes and a predicate returns true
- **THEN** that case's builder function is executed
- **THEN** subsequent cases are not evaluated

#### Scenario: Range matching with predicates
- **WHEN** `whenMatch((age) => age >= 18 && age < 65, builder)` is defined
- **THEN** selector values within the range match the case
- **THEN** selector values outside the range do not match

### Requirement: Fallback case handling

The system SHALL provide an `otherwise()` method for defining a default case when no matches are found.

#### Scenario: Defining a fallback case
- **WHEN** `otherwise(builder)` is called on a switch builder
- **THEN** the fallback builder is stored
- **THEN** a `Railway<E, C>` instance is returned to continue the chain

#### Scenario: Fallback executes when no match
- **WHEN** the switch executes and no case matches
- **THEN** the `otherwise()` builder function is executed
- **THEN** the fallback operations are added to the railway

#### Scenario: Switch without fallback passes through
- **WHEN** `end()` is called instead of `otherwise()`
- **THEN** a `Railway<E, C>` instance is returned
- **THEN** no match results in context passthrough (no operations added)

### Requirement: Short-circuit evaluation

The system SHALL evaluate cases in order and stop after the first match.

#### Scenario: First match wins
- **WHEN** multiple cases could match the selector output
- **THEN** only the first matching case in definition order executes
- **THEN** remaining cases are not evaluated

#### Scenario: Predicates not evaluated after match
- **WHEN** a case matches
- **THEN** subsequent case predicates are not called
- **THEN** only one case builder function executes

### Requirement: Selector evaluated once

The system SHALL evaluate the selector function exactly once per switch execution.

#### Scenario: Selector called at switch execution
- **WHEN** the switch operation executes
- **THEN** the selector function is called with the current context
- **THEN** the selector output is used for all case comparisons

#### Scenario: Selector not re-evaluated per case
- **WHEN** checking multiple cases
- **THEN** the selector function is not called again
- **THEN** the cached selector output is compared against each case

### Requirement: Switch operations participate in main compensation stack

The system SHALL ensure all operations from matched switch cases are added to the main railway's operation list.

#### Scenario: Matched case operations added to railway
- **WHEN** a switch case matches and its builder adds steps
- **THEN** those steps are appended to the railway's main operation list
- **THEN** the steps participate in the main compensation stack

#### Scenario: Switch case compensation behavior
- **WHEN** a step within a matched switch case fails
- **THEN** all prior operations (including pre-switch operations) compensate
- **THEN** compensation follows the standard railway compensation order

#### Scenario: No isolated sub-railway execution
- **WHEN** a switch case builder executes
- **THEN** it adds operations to the parent railway instance
- **THEN** it does not create a separate Railway.run() execution context

### Requirement: Type safety for switch selector

The system SHALL enforce type safety for the selector function and case values.

#### Scenario: Selector type determines case value type
- **WHEN** `switchOn<T>(selector)` is called with a selector returning type `T`
- **THEN** all `when(value, builder)` calls must provide values of type `T`
- **THEN** the compiler enforces type compatibility

#### Scenario: Predicate receives selector type
- **WHEN** `whenMatch(predicate, builder)` is called
- **THEN** the predicate function receives the same type `T` as the selector output
- **THEN** the compiler enforces type safety

### Requirement: Switch case builders receive railway instance

The system SHALL pass the current railway instance to each case builder function.

#### Scenario: Case builder receives railway
- **WHEN** a case builder function is executed
- **THEN** it receives a `Railway<E, C>` instance as a parameter
- **THEN** the builder can add steps, guards, or nested switches

#### Scenario: Case builder returns railway
- **WHEN** a case builder function completes
- **THEN** it returns a `Railway<E, C>` instance
- **THEN** the returned railway's operations are merged into the parent

### Requirement: Empty switch handling

The system SHALL handle switches with no cases defined.

#### Scenario: Switch with no cases and no otherwise
- **WHEN** `switchOn(selector).end()` is called with no `when()` cases
- **THEN** the switch operation passes context through unchanged
- **THEN** the selector is still evaluated (for potential side effects)

#### Scenario: Switch with no cases but with otherwise
- **WHEN** `switchOn(selector).otherwise(builder)` is called with no `when()` cases
- **THEN** the otherwise builder always executes
- **THEN** the selector is still evaluated

### Requirement: Switch error handling for selector failures

The system SHALL handle errors from selector function evaluation.

#### Scenario: Selector throws exception
- **WHEN** the selector function throws an exception during evaluation
- **THEN** the exception is caught and wrapped in the railway error type `E`
- **THEN** the railway returns `Left(error)` without evaluating cases

#### Scenario: Selector returns normally
- **WHEN** the selector function completes without throwing
- **THEN** case evaluation proceeds normally
- **THEN** the switch matches based on the selector output
