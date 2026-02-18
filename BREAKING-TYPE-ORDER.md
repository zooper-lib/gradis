# BREAKING: Fix Either Type Parameter Order

## Problem

The current type parameter order is **backwards and confusing**.

### Current (Confusing) Implementation

```dart
abstract class RailwayStep<C, E> {
  //                         ^  ^
  //                         |  └─ E (Error) - SECOND parameter
  //                         └──── C (Context) - FIRST parameter
  
  Future<Either<E, C>> run(C context);
  //            ^  ^
  //            |  └─ C (Context) - Right (success)
  //            └──── E (Error) - Left (failure)
}

// Usage - THIS IS CONFUSING:
class CreateUserStep extends RailwayStep<UserContext, UserError> {
  //                                      ^           ^
  //                                      |           └─ Looks like Right but is E (Error)
  //                                      └───────────── Looks like Left but is C (Context)
}
```

**The Problem:**
When you write `RailwayStep<UserContext, UserError>`, it **looks** like:
- UserContext → Left
- UserError → Right

But it's **actually**:
- UserContext → C → Right (success)
- UserError → E → Left (error)

This is **backwards from visual expectation**!

## Solution

Flip the type parameter order to match Either convention: **Error first, Context second**.

### Proposed (Intuitive) Implementation

```dart
abstract class RailwayStep<E, C> {
  //                         ^  ^
  //                         |  └─ C (Context) - SECOND parameter
  //                         └──── E (Error) - FIRST parameter
  
  Future<Either<E, C>> run(C context);
  //            ^  ^
  //            |  └─ C (Context) - Right (success)
  //            └──── E (Error) - Left (failure)
}

// Usage - NOW IT MAKES SENSE:
class CreateUserStep extends RailwayStep<UserError, UserContext> {
  //                                      ^          ^
  //                                      |          └─ C → Right (success)
  //                                      └──────────── E → Left (error)
}
```

**Now when you write `RailwayStep<UserError, UserContext>`, it matches Either:**
- UserError → E → Left (error) ✓
- UserContext → C → Right (success) ✓

**Visual alignment:**
```dart
RailwayStep<UserError, UserContext>
Either<UserError, UserContext>
            ^          ^
            |          └─ Right (success)
            └──────────── Left (error)
```

## Required Changes

### 1. RailwayStep
```dart
// Before
abstract class RailwayStep<C, E> {
  Future<Either<E, C>> run(C context);
  Future<void> compensate(C context) async {}
}

// After
abstract class RailwayStep<E, C> {
  Future<Either<E, C>> run(C context);
  Future<void> compensate(C context) async {}
}
```

### 2. RailwayGuard
```dart
// Before
abstract interface class RailwayGuard<C, E> {
  Future<Either<E, void>> check(C context);
}

// After
abstract interface class RailwayGuard<E, C> {
  Future<Either<E, void>> check(C context);
}
```

### 3. Railway
```dart
// Before
class Railway<C, E> {
  // ...
}

// After
class Railway<E, C> {
  // ...
}
```

### 4. _Operation
```dart
// Before
class _Operation<C, E> {
  // ...
}

// After
class _Operation<E, C> {
  // ...
}
```

### 5. All Usage Sites

Every usage must flip the order:

```dart
// Before
Railway<UserContext, UserError>()
  .step(CreateUserStep<UserContext, UserError>())

// After
Railway<UserError, UserContext>()
  .step(CreateUserStep<UserError, UserContext>())
```

## Migration Impact

This is a **BREAKING CHANGE** affecting:
- ✅ All Railway usages
- ✅ All RailwayStep implementations
- ✅ All RailwayGuard implementations
- ✅ All test code

**Migration:**
Find: `Railway<(\w+Context), (\w+Error)>`
Replace: `Railway<$2, $1>`

Find: `RailwayStep<(\w+Context), (\w+Error)>`
Replace: `RailwayStep<$2, $1>`

Find: `RailwayGuard<(\w+Context), (\w+Error)>`
Replace: `RailwayGuard<$2, $1>`

## Benefits

1. **Visual Consistency**: Type parameter order matches Either convention
2. **Cognitive Load**: No mental mapping from position to meaning
3. **Standard Convention**: Matches Rust's `Result<T, E>`, Scala's `Either[L, R]` when used for errors
4. **Less Confusing**: Error first is the common pattern in error handling types

## Comparison with Other Languages

**Rust:**
```rust
Result<T, E>  // Success first, Error second
// But Result is NOT the same as Either semantics
```

**Scala (cats):**
```scala
Either[Error, Success]  // Error first (Left), Success second (Right)
```

**Haskell:**
```haskell
Either a b  -- Left is 'a', Right is 'b'
-- Convention: Either Error Success
```

**TypeScript (fp-ts):**
```typescript
Either<Error, Success>  // Error first (Left), Success second (Right)
```

**Our convention should match Either semantics:** Error first, Success second.

## Decision

**IMPLEMENT THIS CHANGE** - It fixes a fundamental usability issue where the visual order conflicts with semantic meaning.

---

**Status**: 🔴 Critical - Should be fixed before v2.0 release
**Breaking Change**: Yes - requires migration
**Complexity**: Medium (lots of find/replace)
**Priority**: High (usability issue)
