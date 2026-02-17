## Context

The `gradis` package implements a railway-oriented programming pattern for Dart application-layer workflows. It addresses the need for strongly-typed, declarative orchestration that separates validation (guards) from state mutation (steps) while maintaining predictable error handling and UX control.

Current state: No existing workflow orchestration package exists in the codebase. Workflows are implemented ad-hoc within use cases, leading to inconsistent error handling patterns and difficulty separating validation from mutation logic.

Constraints:
- Must use `either_dart` for Either type (project dependency standard)
- Must avoid runtime casting and Object-based errors
- Must support immutable context propagation
- Must remain infrastructure-only (no transaction management)
- Must work within Clean Architecture/DDD application layer

## Goals / Non-Goals

**Goals:**
- Provide a builder-style API for composing guards and steps into railways
- Enable strongly-typed context that accumulates results through the pipeline
- Implement automatic short-circuiting on first error
- Support single unified error type per railway (defined by railway owner)
- Keep railway definitions declarative and readable
- Separate validation concerns (guards) from mutation concerns (steps)
- Allow railways to own their transaction boundaries

**Non-Goals:**
- Parallel branch execution (future extension)
- Compensating rollback logic or saga orchestration (future extension)
- Automatic logging or progress streaming (future extension)
- Transaction management within the railway (remains at workflow layer)
- Generic error mapping utilities (responsibility of guards/steps)

## Decisions

### 1. Immutable Builder Pattern for Railway Construction

**Decision**: Use immutable builder pattern where each `guard()` and `step()` call returns a new `Railway` instance.

**Rationale**: 
- Prevents accidental mutation of shared railway definitions
- Enables railway reuse and composition
- Aligns with functional programming principles
- Makes testing and reasoning easier

**Alternative Considered**: Mutable chaining (Flutter-style) was rejected because it risks shared state bugs and makes railway instances less predictable.

**Implementation**:
```dart
Railway<C, E> guard(RailwayGuard<C, E> guard) {
  return Railway([..._pipeline, guard.check]);
}
```

### 2. Separate Guard and Step Abstractions

**Decision**: Define distinct interfaces for `RailwayGuard<C, E>` (validation) and `RailwayStep<C, E>` (mutation).

**Rationale**:
- Guards perform read-only validation and return `Either<E, void>`
- Steps perform state changes and return `Either<E, C>` with updated context
- Separation makes intent explicit and prevents guards from accidentally mutating state
- Enables future optimizations (e.g., parallel guard execution)

**Alternative Considered**: Single `RailwayOperation` interface was rejected because it blurs the distinction between validation and mutation, making workflows harder to reason about.

### 3. Context as Immutable Data Carrier

**Decision**: Require workflow context to be immutable with `copyWith` pattern for updates.

**Rationale**:
- Prevents unintended side effects between steps
- Makes data flow explicit and traceable
- Supports debugging and testing
- Aligns with functional programming model

**Convention**: Context classes should be `final class` with `copyWith` method for updating accumulated results while preserving input data.

### 4. Single Error Type Per Railway

**Decision**: Each railway defines exactly one error type `E` that all guards and steps must map to.

**Rationale**:
- Eliminates runtime casting and `Object` error handling
- Forces explicit error mapping at guard/step level (where context exists)
- Keeps railway free of error-mapping logic
- Ensures UX-consistent error handling

**Responsibility**: Guards and steps own error mapping from internal use case/repository errors to railway error type.

### 5. Railway as Pure Execution Engine

**Decision**: Railway only executes the pipeline and propagates Either results. No error mapping, no logging, no transaction management.

**Rationale**:
- Single responsibility: execute guard/step sequence
- Transaction boundaries belong to the usage layer (where transactional runner exists)
- Logging hooks can be added later without changing core abstraction
- Keeps railway simple and focused

**Implementation**:
```dart
Future<Either<E, C>> run(C initial) async {
  var current = Right<E, C>(initial);
  for (final operation in _pipeline) {
    current = await current.flatMapAsync(operation);
    if (current.isLeft) break; // short-circuit
  }
  return current;
}
```

### 6. Either-Based Short-Circuiting

**Decision**: Use `either_dart` package and leverage `flatMapAsync` for automatic short-circuit behavior.

**Rationale**:
- `flatMapAsync` only executes if previous result was Right
- Natural short-circuit without explicit checks
- Functional composition aligns with railway metaphor
- Consistent with Either patterns in application layer

**Alternative Considered**: Manual loop with early return was rejected because it's more verbose and error-prone.

## Risks / Trade-offs

**[Risk]** Learning curve for teams unfamiliar with railway-oriented programming or Either types  
→ **Mitigation**: Provide comprehensive examples, package README with usage patterns, and reference documentation

**[Risk]** Verbose context classes with many `copyWith` parameters in complex workflows  
→ **Mitigation**: Accept this trade-off for type safety; future tooling could generate context classes

**[Risk]** Error mapping boilerplate in guards/steps  
→ **Mitigation**: This is intentional - explicit mapping ensures UX control; accept the verbosity for clarity

**[Trade-off]** Immutable builder creates new instances on each chain operation  
→ **Impact**: Minor memory overhead vs. safety and composability; acceptable for railway use case

**[Trade-off]** No built-in logging or progress tracking  
→ **Impact**: Railways are less observable initially; can be added via hooks in future without breaking changes

**[Trade-off]** Single error type per railway may feel restrictive  
→ **Impact**: Forces discipline in error modeling; ensures consistent UX; benefits outweigh flexibility loss
