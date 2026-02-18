## Why

The current Railway API has two critical issues: (1) type parameter order `<C, E>` is backwards from Either convention, creating cognitive confusion where `RailwayStep<UserContext, UserError>` visually implies UserContext→Left but actually means UserContext→Right, and (2) chained `branch()` calls for mutually exclusive routing are verbose, evaluate all predicates unnecessarily, and lack clear intent for exclusive choice patterns like user type workflows or status-based routing.

## What Changes

- **BREAKING**: Flip type parameter order from `<C, E>` to `<E, C>` across all core types (Railway, RailwayStep, RailwayGuard) to match Either's `<Left, Right>` convention where Error is Left and Context is Right
- **BREAKING**: Update all generic type declarations and usage sites to use `<E, C>` order
- **NEW**: Add `switchOn()` pattern-matching API for exclusive choice routing with value matching, predicate matching, and optional fallback cases
- **NEW**: Introduce `SwitchBuilder<E, C, T>` with `when()`, `whenMatch()`, and `otherwise()` methods for declarative route definitions
- Ensure all switch cases participate in the main Railway's compensation stack (not isolated sub-routines)

## Capabilities

### New Capabilities
- `workflow-switching`: Exclusive choice routing with pattern-matching style switch/case semantics, supporting value equality matching, predicate-based matching, and fallback cases within a single Railway execution context

### Modified Capabilities
- `workflow-core`: Railway type parameters change from `<C, E>` to `<E, C>` 
- `workflow-steps`: RailwayStep type parameters change from `<C, E>` to `<E, C>`
- `workflow-guards`: RailwayGuard type parameters change from `<C, E>` to `<E, C>`

## Impact

**Breaking Changes:**
- All existing Railway, RailwayStep, and RailwayGuard implementations must swap type parameter order
- All consumer code using generic type annotations must be updated
- Migration required: find/replace `Railway<(\w+), (\w+)>` → `Railway<$2, $1>` (and similar for Step/Guard)
- Should be released as v2.0 due to breaking API changes

**New Functionality:**
- Backwards compatible addition of switchOn() API
- Enables cleaner, more declarative routing patterns for common use cases (user types, status workflows, age-based flows)
- Improves performance by short-circuiting on first match vs evaluating all branch predicates
- All switch cases share the main Railway's compensation stack for consistent error handling

**Affected Code:**
- Core: `lib/src/railway.dart`, `lib/src/railway_step.dart`, `lib/src/railway_guard.dart`
- Tests: All test files require type parameter order updates
- Examples: `example/main.dart` requires updates
- Documentation: All generic type examples in comments and README
