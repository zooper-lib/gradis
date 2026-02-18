# Gradis

A railway-oriented programming package for Dart providing strongly-typed, declarative workflow orchestration with guards and steps.

## Overview

Gradis implements a railway pattern for application-layer workflows in Clean Architecture/DDD systems. It separates validation (guards) from state mutation (steps) while maintaining predictable error handling and type safety.

## Features

- **Strongly-typed context propagation** through workflow pipelines
- **Separate guard and step abstractions** for validation vs mutation
- **Immutable builder pattern** for composable railway definitions
- **Automatic short-circuiting** on first error
- **Single unified error type** per railway (no runtime casting)
- **Transaction-agnostic** execution
- **Compensation/rollback** for failed workflows (Saga pattern)
- **Conditional branching** with predicate-based execution
- **Switch pattern** for exclusive choice routing

## Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  gradis: ^2.0.0
```

## Core Concepts

### Type Parameter Convention

**Important**: Gradis v2.0.0 uses the `<E, C>` type parameter order:

```dart
Railway<E, C>       // E = Error type (Left), C = Context type (Right)
RailwayGuard<E, C>
RailwayStep<E, C>
```

This matches the `Either<L, R>` convention from the `either_dart` package, making Railway → Either conversions more intuitive:

```dart
Railway<MyError, MyContext> → Either<MyError, MyContext>
```

**Migration from v1.x**: All type parameters must be reversed. See the [Migration Guide](#migration-from-v1x) below.

### Railway

A `Railway<E, C>` orchestrates a workflow by composing guards and steps into a pipeline:

- `E`: The unified error type for the workflow (Left channel)
- `C`: The context type that flows through the pipeline (Right channel)

### Guards

Guards perform **read-only validation** without mutating the context:

```dart
class EmailGuard implements RailwayGuard<CreateUserError, CreateUserContext> {
  @override
  Future<Either<CreateUserError, void>> check(CreateUserContext context) async {
    if (!context.email.contains('@')) {
      return Left(CreateUserError.invalidEmail);
    }
    return const Right(null);
  }
}
```

Guards return `Right(null)` on success or `Left(error)` on validation failure.

### Steps

Steps perform **state mutation** and return an updated context:

```dart
class CreateUserStep extends RailwayStep<CreateUserError, CreateUserContext> {
  @override
  Future<Either<CreateUserError, CreateUserContext>> run(CreateUserContext context) async {
    final userId = await _repository.createUser(context.email);
    return Right(context.copyWith(userId: userId));
  }
  
  @override
  Future<void> compensate(CreateUserContext context) async {
    // Optional: cleanup/rollback on downstream failure
    await _repository.deleteUser(context.userId!);
  }
}
```

Steps return `Right(updated context)` on success or `Left(error)` on failure. Optionally override `compensate()` to handle rollback when downstream steps fail.

### Context

Context is an immutable object that travels through the railway:

```dart
final class CreateUserContext {
  final String email;
  final String? userId;
  
  const CreateUserContext({required this.email, this.userId});
  
  CreateUserContext copyWith({String? userId}) {
    return CreateUserContext(email: email, userId: userId ?? this.userId);
  }
}
```

Use the `copyWith` pattern to update context immutably in steps.

## Usage Examples

### Basic Railway Composition

```dart
final railway = Railway<CreateUserError, CreateUserContext>()
    .guard(EmailGuard())
    .guard(PasswordGuard())
    .step(CreateUserStep())
    .step(SendVerificationStep());

final context = CreateUserContext(email: 'user@example.com', password: 'secure');
final result = await railway.run(context);

result.fold(
  (error) => print('Error: $error'),
  (ctx) => print('Success! User ID: ${ctx.userId}'),
);
```

### Error Mapping Pattern

Guards and steps are responsible for mapping internal errors to the railway error type:

```dart
class CreateUserStep implements RailwayStep<CreateUserError, CreateUserContext> {
  final UserRepository repository;
  
  @override
  Future<Either<CreateUserError, CreateUserContext>> run(CreateUserContext context) async {
    // Repository returns its own error type
    final result = await repository.create(context.email);
    
    // Map repository error to workflow error
    return result.fold(
      (repositoryError) {
        if (repositoryError == RepositoryError.alreadyExists) {
          return Left(CreateUserError.userExists);
        }
        return Left(CreateUserError.saveFailed);
      },
      (userId) => Right(context.copyWith(userId: userId)),
    );
  }
}
```

This keeps error mapping localized and the railway free of error-handling logic.

### Compensation Pattern (Saga)

When a step fails, Gradis automatically executes compensation functions in reverse order for all previously executed steps:

```dart
class ReserveInventoryStep extends RailwayStep<OrderError, OrderContext> {
  @override
  Future<Either<OrderError, OrderContext>> run(OrderContext context) async {
    await _inventory.reserve(context.productId, context.quantity);
    return Right(context.copyWith(inventoryReserved: true));
  }
  
  @override
  Future<void> compensate(OrderContext context) async {
    // Rollback: release the reservation
    await _inventory.release(context.productId, context.quantity);
  }
}

class ProcessPaymentStep extends RailwayStep<OrderError, OrderContext> {
  @override
  Future<Either<OrderError, OrderContext>> run(OrderContext context) async {
    final result = await _payment.charge(context.amount);
    if (result.failed) return Left(OrderError.paymentFailed);
    return Right(context.copyWith(paymentId: result.id));
  }
  
  @override
  Future<void> compensate(OrderContext context) async {
    // Rollback: refund the charge
    await _payment.refund(context.paymentId!);
  }
}

final railway = Railway<OrderError, OrderContext>()
    .step(ReserveInventoryStep())  // If payment fails...
    .step(ProcessPaymentStep());    // ...inventory is auto-released
```

Compensations are **best-effort** - errors during compensation are logged but don't fail the workflow.

### Branching Pattern

Add conditional logic to your railway with `branch()`:

```dart
final railway = Railway<OrderError, OrderContext>()
    .step(ValidateOrderStep())
    .branch(
      (ctx) => ctx.isPremiumUser,
      (r) => r.step(ApplyPremiumDiscountStep()),
    )
    .step(ProcessPaymentStep());
```

The predicate is evaluated once, and the branch only executes if true. Branch steps participate in the compensation chain.

### Switch Pattern

Use `switchOn()` for exclusive choice routing based on a selector value. This is ideal for workflows that need different execution paths based on state:

#### Value Matching with `when()`

```dart
final railway = Railway<OrderError, OrderContext>()
    .step(ValidateOrderStep())
    .switchOn<OrderStatus>((ctx) => ctx.status)
      .when(OrderStatus.draft, (r) => r.step(ValidateDraftStep()))
      .when(OrderStatus.pending, (r) => r.step(ProcessPendingStep()))
      .when(OrderStatus.approved, (r) => r.step(FulfillOrderStep()))
      .otherwise((r) => r.step(HandleUnknownStatusStep()))
    .step(LogOrderStep());
```

#### Predicate Matching with `whenMatch()`

For conditional matching rather than exact values:

```dart
final railway = Railway<UserError, UserContext>()
    .step(CreateUserStep())
    .switchOn<String>((ctx) => ctx.email.split('@').last)
      .whenMatch(
        (domain) => domain.endsWith('.gov') || domain.endsWith('.edu'),
        (r) => r.step(GrantAdminPermissionsStep()),
      )
      .whenMatch(
        (domain) => domain.contains('example'),
        (r) => r.step(CreateGuestSessionStep()),
      )
      .otherwise((r) => r.step(SetupUserDashboardStep()))
    .step(SendVerificationEmailStep());
```

#### Switch Execution Rules

- The selector function is evaluated **once** when the switch is reached
- Cases are checked **in order** until the first match
- Only the **first matching case** executes (short-circuit evaluation)
- Use `otherwise()` for a fallback when no cases match
- Use `end()` instead of `otherwise()` if no fallback is needed (no-op)
- All operations from the matched case are added to the parent railway's operation list
- Switch operations **participate in the compensation chain** if downstream steps fail

See [example/main.dart](example/main.dart) for complete switch pattern examples.

### Context Immutability Pattern

Always use immutable context updates:

```dart
// ✅ Good - immutable update
class IncrementStep extends RailwayStep<CounterError, CounterContext> {
  @override
  Future<Either<CounterError, CounterContext>> run(CounterContext context) async {
    return Right(context.copyWith(count: context.count + 1));
  }
}

// ❌ Bad - mutable update (don't do this)
class BadStep extends RailwayStep<CounterError, CounterContext> {
  @override
  Future<Either<CounterError, CounterContext>> run(CounterContext context) async {
    context.count++; // This won't compile if context is properly immutable
    return Right(context);
  }
}
```

### Transaction Boundaries

Railways don't manage transactions - that's the caller's responsibility:

```dart
// Wrap railway execution in a transaction
await transactionRunner.run(() async {
  final railway = Railway<CreateUserError, CreateUserContext>()
      .step(CreateUserStep())
      .step(CreateAccountStep());
  
  return await railway.run(context);
});
```

## Design Principles

1. **Builder Pattern**: Each `guard()` and `step()` call returns a new railway instance
2. **Immutable Context**: Context flows through the pipeline without mutation
3. **Single Error Type**: Each workflow defines exactly one error type
4. **Guards vs Steps**: Clear separation between validation and mutation
5. **No Runtime Casting**: Type safety enforced at compile time
6. **Declarative Workflows**: Railway definitions remain clean and readable

## Complete Example

See [example/main.dart](example/main.dart) for a complete working example.

## License

See LICENSE file.
