## Context

The Railway pattern library is approaching stability with core features (steps, guards, branching, compensation) implemented. However, two significant issues block a stable v2 release:

1. **Type Parameter Confusion**: Current `<C, E>` order creates cognitive dissonance. When writing `Railway<UserContext, UserError>`, developers naturally expect the visual order to match Either's `<Left, Right>` semantics, but it's backwards (Context→Right, Error→Left despite Error appearing second).

2. **Routing Pattern Gap**: While `branch()` works for conditional logic, mutually exclusive routing scenarios (user types, status workflows, age-based flows) require verbose chaining with poor performance characteristics (all predicates evaluate) and unclear intent.

**Current State**: Railway core is functional but these API ergonomics issues should be fixed before announcing v2.0 as stable.

**Constraints**:
- Must maintain Either's `Left = Error, Right = Success` semantics
- Breaking changes acceptable now (pre-v2 release)
- New features should integrate seamlessly with existing compensation/branching

## Goals / Non-Goals

**Goals:**
- Fix type parameter order to match Either convention (`<E, C>` where E→Left/Error, C→Right/Context)
- Provide first-class switch/router API for exclusive choice patterns
- Maintain backward compatibility for compensation behavior (all switch cases participate in main stack)
- Enable type-safe pattern matching with compile-time guarantees
- Short-circuit evaluation (stop after first match in switch)

**Non-Goals:**
- Provide migration tooling beyond regex patterns (manual migration acceptable for pre-v2)
- Support nested Railway instances within switch cases (use sub-routine pattern if needed)
- Type narrowing within switch cases (Dart's type system doesn't support this elegantly)
- Maintain compatibility with existing `<C, E>` code (clean break for v2)

## Decisions

### Decision 1: Type Parameter Order `<E, C>`

**Choice**: Use `<E, C>` (Error, Context) order across all generic types.

**Rationale**:
- Matches Either's `Left = Error, Right = Success` convention visually
- Aligns with TypeScript (fp-ts), Scala (cats), Haskell convention for error-handling Either types
- Reduces cognitive load: `Railway<UserError, UserContext>` now reads naturally (error handling for user context)
- Rust's `Result<T, E>` is NOT analogous (success-first, not Either semantics)

**Alternatives Considered**:
- Keep `<C, E>`: Rejected - maintains confusion
- Add type aliases: Rejected - creates two ways to do the same thing
- Make it configurable: Rejected - API surface explosion

**Implementation**:
- Change all `class X<C, E>` to `class X<E, C>` 
- Update internal `_Operation<C, E>` to `_Operation<E, C>`
- Preserve `Either<E, C>` order in return types (already correct)
- No runtime behavior changes, purely compile-time

### Decision 2: Pattern-Matching Switch API

**Choice**: Implement `switchOn()` with fluent builder returning `SwitchBuilder<E, C, T>`.

**API Surface**:
```dart
class Railway<E, C> {
  SwitchBuilder<E, C, T> switchOn<T>(T Function(C) selector);
}

class SwitchBuilder<E, C, T> {
  SwitchBuilder<E, C, T> when(T value, Railway<E, C> Function(Railway<E, C>) builder);
  SwitchBuilder<E, C, T> whenMatch(bool Function(T) predicate, Railway<E, C> Function(Railway<E, C>) builder);
  Railway<E, C> otherwise(Railway<E, C> Function(Railway<E, C>) builder);
  Railway<E, C> end(); // No otherwise → passthrough
}
```

**Rationale**:
- Fluent API matches existing Railway builder pattern
- `when()` for value equality, `whenMatch()` for predicates/ranges
- Returns Railway (not SwitchBuilder) from `otherwise()`/`end()` to continue main chain
- Selector evaluated once, cases checked in order, first match wins (short-circuit)
- All matched operations added to main Railway's operation list (shared compensation)

**Alternatives Considered**:
- Map-based switch `{case: builder}`: Rejected - less fluent, no ordering guarantee
- Sub-routine pattern (nested Railway.run()): Rejected - isolated compensation, not true switching
- Extension on context: Rejected - breaks Railway builder pattern

**Implementation Strategy**:
1. `switchOn()` creates `SwitchBuilder` capturing selector function
2. `when()`/`whenMatch()` append cases to internal `List<_SwitchCase>`
3. `otherwise()`/`end()` create a `_SwitchOperation` and add to Railway's operations
4. At runtime, `_SwitchOperation.execute()`:
   - Evaluates selector once with current context
   - Iterates cases until first match
   - Executes matched builder to get sub-railway
   - Merges sub-railway operations into parent (shared stack)
   - Returns context (potentially transformed by matched operations)

### Decision 3: Switch Integration with Compensation

**Choice**: All switch case operations participate in the main Railway's compensation stack.

**Rationale**:
- Matches existing `branch()` behavior (branches compensate as part of main flow)
- Switch is routing logic, not a transaction boundary
- Simpler mental model: one Railway = one compensation chain
- If isolation needed, users can wrap in a custom step that runs a sub-Railway

**Implementation**:
- Matched case's builder receives the current Railway instance (or a proxy)
- Operations added by builder are appended to main `_operations` list
- No separate compensation context needed
- Failed steps in switch cases trigger compensation of all prior operations (including pre-switch)

### Decision 4: Migration Strategy

**Choice**: Breaking change with regex-based migration guidance, no automated tooling.

**Rationale**:
- Pre-v2 release acceptable time for breaking changes
- Type parameter swap is mechanical (find/replace)
- Small user base currently (minimal migration pain)
- Clean break better than maintaining legacy compatibility

**Migration Path**:
1. Announce breaking change in CHANGELOG with migration guide
2. Provide regex patterns:
   - `Railway<(\w+), (\w+)>` → `Railway<$2, $1>`
   - `RailwayStep<(\w+), (\w+)>` → `RailwayStep<$2, $1>`
   - `RailwayGuard<(\w+), (\w+)>` → `RailwayGuard<$2, $1>`
3. Update all examples and tests in same PR
4. Release as v2.0.0 with clear upgrade notes

**Rollback**: Not applicable (semantic change only, can revert PR if needed pre-release)

## Risks / Trade-offs

**Risk: Breaking all existing users**  
→ Mitigation: Clear migration guide, timed with v2 announcement, small user base currently

**Risk: Switch API complexity increase**  
→ Mitigation: Optional feature, existing `branch()` still works for simple cases

**Risk: Compilation errors don't clearly indicate fix**  
→ Mitigation: Document migration patterns in error guide, provide examples

**Trade-off: No automatic migration tooling**  
→ Accepted: Mechanical change, tooling overhead not justified for pre-v2 user base

**Risk: Switch edge cases (no match, selector throws)**  
→ Mitigation: `otherwise()` handles no-match, selector errors propagate as Left (caught by Railway error handling)

**Trade-off: Dart's type system can't narrow types in switch cases**  
→ Accepted: All cases return same `Railway<E, C>`, type narrowing would require advanced generics

**Risk: Performance overhead of builder API**  
→ Mitigation: Builder pattern is compile-time, runtime cost is just case iteration (same as manual if/else)

## Open Questions

1. **Should selector evaluation be lazy (per-case) or eager (once upfront)?**  
   Current design: Eager (evaluate once). Lazy could allow dynamic behavior but adds complexity.

2. **Should we support fallthrough or multi-match?**  
   Current design: First match wins (short-circuit). Fallthrough conflicts with exclusive choice semantics.

3. **Error handling: What if selector function throws?**  
   Proposed: Catch and wrap in Left, similar to step execution. Needs testing/documentation.

4. **Should switch support empty case list?**  
   Proposed: Allow (becomes passthrough), but may want validation warning.
