## Context

The Railway class currently implements an immutable builder pattern for composing guards and steps into a workflow pipeline. The pipeline stores functions `Future<Either<E, C>> Function(C)` and executes them sequentially, short-circuiting on the first error.

**Current limitations:**
- No mechanism for cleanup or rollback when a step fails after other steps have already modified state
- No support for conditional execution paths based on runtime context
- Guards and steps are linear - no branching logic

**Stakeholders:**
- Users building complex workflows requiring transactional semantics (all-or-nothing execution)
- Users needing conditional workflow paths based on business logic

## Goals / Non-Goals

**Goals:**
- Enable each step to define a cleanup/undo operation that executes if a later step fails
- Execute compensations in reverse order (LIFO) when pipeline encounters an error
- Support conditional branching where the railway can execute different sub-pipelines based on a predicate
- Maintain the immutable builder pattern and existing API ergonomics
- Minimize breaking changes while achieving necessary interface modifications

**Non-Goals:**
- Automatic compensation inference (users must explicitly implement compensate logic)
- Nested transaction isolation or ACID guarantees (compensation is best-effort cleanup)
- Parallel branch execution (branches execute sequentially based on first matching predicate)
- Compensation of guards (guards are read-only and don't require cleanup)

## Decisions

### Decision 1: Compensation Stack in Pipeline Tracking

**Choice:** Store compensation functions alongside operations in the pipeline, building a compensation stack during execution.

**Rationale:**
- Fits the immutable builder pattern - compensation functions are captured when steps are added
- Reverse execution order (LIFO) is natural for a stack
- Allows each step to access the context at the point it executed for accurate cleanup

**Alternatives considered:**
- Store compensations separately from pipeline → rejected, adds complexity and breaks encapsulation
- No explicit stack, just reverse the step list → rejected, guards shouldn't be compensated

**Implementation approach:**
- Change `_pipeline` from `List<Function(C)>` to a structure that includes both the operation and optional compensation
- Track compensation functions only for steps, not guards
- During execution, build a runtime compensation stack of executed steps

### Decision 2: Make `compensate` an Optional Method with Default

**Choice:** Add `compensate` method to `RailwayStep` interface with a default empty implementation.

```dart
abstract interface class RailwayStep<C, E> {
  Future<Either<E, C>> run(C context);
  
  Future<void> compensate(C context) async {}
}
```

**Rationale:**
- BREAKING but minimally so - existing implementations can add empty override or rely on default
- Explicit in the interface - compensation is a first-class concern
- Optional behavior - steps that don't need compensation can ignore it
- Receives the context that was current when the step executed (captured at runtime)

**Alternatives considered:**
- Separate `CompensatableStep` interface → rejected, splits the abstraction and complicates API
- Compensation function as optional parameter to `step()` → rejected, breaks builder pattern ergonomics
- No default implementation → rejected, forces all existing steps to change even if they don't need compensation

### Decision 3: Compensation Execution Strategy

**Choice:** When pipeline fails, execute compensations for all successfully completed steps in reverse order, ignoring compensation errors.

**Rationale:**
- Best-effort cleanup - compensation failures shouldn't mask the original error
- LIFO order ensures cleanup happens in reverse dependency order
- Only compensate steps that actually executed (not steps after the failure point)

**Implementation:**
```dart
// Pseudocode
compensationStack = []
for each operation in pipeline:
  result = await operation(context)
  if result.isLeft:
    // Execute compensations in reverse
    for comp in compensationStack.reverse():
      try { await comp(context) } catch { /* log but continue */ }
    return Left(originalError)
  if operation is step:
    compensationStack.add((ctx) => step.compensate(ctx))
  context = result.right
```

**Alternatives considered:**
- Stop on first compensation error → rejected, defeats purpose of cleanup
- Return compensation errors → rejected, original error is more important
- Execute compensations even on success → rejected, compensation is only for rollback

### Decision 4: Branch API Design

**Choice:** Add `branch` method that takes a predicate and a sub-railway builder.

```dart
Railway<C, E> branch(
  bool Function(C) predicate,
  Railway<C, E> Function(Railway<C, E>) builder,
)
```

**Usage:**
```dart
railway
  .step(stepA)
  .branch(
    (ctx) => ctx.isAdmin,
    (r) => r.step(adminOnlyStep),
  )
  .step(stepB)
```

**Rationale:**
- Predicate uses current context to make branching decision
- Builder pattern maintains immutability - creates a new Railway for branch operations
- Branch sub-pipeline inherits the compensation stack from parent
- Clean, composable API that fits existing builder style

**Alternatives considered:**
- Multiple branches with fallthrough → rejected, adds complexity and ambiguity
- Switch-style branching → rejected, can be built on top of single branch primitive
- Branch returns different railway types → rejected, breaks type safety and composability

**Execution behavior:**
- Evaluate predicate with current context
- If true, execute the branch sub-pipeline
- If false, skip the branch (context passes through unchanged)
- Branch compensations integrate into main compensation stack

### Decision 5: Pipeline Internal Structure

**Choice:** Change internal structure to track both operations and compensations.

```dart
final class Railway<C, E> {
  final List<_Operation<C, E>> _operations;
  
  const Railway([this._operations = const []]);
}

class _Operation<C, E> {
  final Future<Either<E, C>> Function(C) execute;
  final Future<void> Function(C)? compensate;
  
  const _Operation(this.execute, [this.compensate]);
}
```

**Rationale:**
- Encapsulates operation + compensation pairing
- Makes it explicit which operations have compensations
- No change to public API surface beyond new methods

## Risks / Trade-offs

**Risk: Breaking change to RailwayStep interface**
- **Mitigation:** Default implementation of `compensate` means existing code continues to work, just needs recompilation. Document in changelog and migration guide.

**Risk: Compensation logic errors could leave partial state**
- **Mitigation:** Document that compensations are best-effort. Users should design idempotent compensations where possible. Consider providing testing utilities to verify compensation behavior.

**Risk: Increased complexity in Railway.run() execution logic**
- **Mitigation:** Maintain clear separation between forward execution and compensation. Use comprehensive tests to verify all execution paths (success, failure, failure during compensation).

**Trade-off: Memory overhead for compensation stack**
- **Impact:** Each executed step stores a compensation closure until pipeline completes
- **Mitigation:** Acceptable for typical workflow sizes. Document that very long-running pipelines should be broken into smaller chunks.

**Trade-off: Branch predicate evaluation happens at runtime**
- **Impact:** Cannot validate or optimize branch coverage at compile-time
- **Mitigation:** Provide clear runtime semantics in documentation. Consider adding debug mode that logs branch decisions.

**Risk: Nested branches could create complex compensation chains**
- **Mitigation:** Document compensation execution order clearly. Provide examples of nested branch compensation behavior.
