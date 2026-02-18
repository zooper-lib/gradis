import 'package:either_dart/either.dart';
import 'railway_guard.dart';
import 'railway_step.dart';

/// Internal structure pairing an operation with its optional compensation.
///
/// This encapsulates both the forward execution function and the optional
/// compensation function that should run if a later operation fails.
class _Operation<C, E> {
  /// The operation to execute (guard check or step run).
  final Future<Either<E, C>> Function(C) execute;

  /// Optional compensation to run if a later operation fails.
  ///
  /// This is null for guards (they are read-only and don't need compensation).
  /// For steps, this calls the step's compensate method with the captured context.
  final Future<void> Function(C)? compensate;

  /// Creates an operation with an execution function and optional compensation.
  const _Operation(this.execute, [this.compensate]);
}

/// A railway-oriented programming builder for composing guards and steps
/// into a strongly-typed workflow pipeline.
///
/// The railway uses an immutable builder pattern where each [guard] and [step]
/// call returns a new [Railway] instance with the operation appended.
///
/// Type parameters:
/// - [C]: The context type that flows through the pipeline
/// - [E]: The unified error type for all operations
final class Railway<C, E> {
  final List<_Operation<C, E>> _operations;

  /// Creates a new railway with an optional existing operations list.
  ///
  /// The operations list defaults to an empty list, creating a railway with no operations.
  const Railway([this._operations = const []]);

  /// Adds a guard to the railway pipeline.
  ///
  /// Returns a new [Railway] instance with the guard's check function appended.
  /// The original railway instance remains unchanged (immutable builder pattern).
  ///
  /// Guards perform read-only validation and do not modify the context.
  Railway<C, E> guard(RailwayGuard<C, E> guard) {
    return Railway([
      ..._operations,
      _Operation(
        (C context) async {
          final result = await guard.check(context);
          return result.fold(
            (error) => Left(error),
            (_) => Right(context),
          );
        },
        // No compensation for guards (read-only)
        null,
      ),
    ]);
  }

  /// Adds a step to the railway pipeline.
  ///
  /// Returns a new [Railway] instance with the step's run function appended.
  /// The original railway instance remains unchanged (immutable builder pattern).
  ///
  /// Steps perform state mutation and return an updated context.
  Railway<C, E> step(RailwayStep<C, E> step) {
    return Railway([
      ..._operations,
      _Operation(
        step.run,
        (C context) => step.compensate(context),
      ),
    ]);
  }

  /// Adds a conditional branch to the railway pipeline.
  ///
  /// The [predicate] function is evaluated with the current context when
  /// the branch is reached during execution. If the predicate returns true,
  /// the operations from the sub-pipeline created by [builder] are executed.
  /// If false, the branch is skipped and context passes through unchanged.
  ///
  /// Branch operations participate in compensation - if a later operation
  /// fails (inside or outside the branch), all executed branch steps are
  /// compensated in reverse order along with the main pipeline.
  ///
  /// Returns a new [Railway] instance with the branch operation appended.
  /// The original railway instance unchanged (immutable builder pattern).
  ///
  /// Example:
  /// ```dart
  /// final railway = Railway<MyContext, MyError>()
  ///   .step(ValidateInput())
  ///   .branch(
  ///     (ctx) => ctx.isAdmin,
  ///     (r) => r
  ///       .guard(AdminPermissionCheck())
  ///       .step(AdminOnlyOperation()),
  ///   )
  ///   .step(CommonStep());
  /// ```
  ///
  /// Nested branches are supported - a branch sub-pipeline can contain
  /// additional branches. Compensation order correctly reflects nesting.
  Railway<C, E> branch(
    bool Function(C) predicate,
    Railway<C, E> Function(Railway<C, E>) builder,
  ) {
    // Build the branch sub-pipeline to extract its operations
    final branchRailway = builder(Railway<C, E>());
    final branchOperations = branchRailway._operations;

    if (branchOperations.isEmpty) {
      // Empty branch - nothing to add
      return this;
    }

    // Shared state for predicate evaluation result
    bool? shouldExecuteBranch;

    // Create wrapped operations that check the predicate result
    final wrappedOperations = <_Operation<C, E>>[];

    for (var i = 0; i < branchOperations.length; i++) {
      final op = branchOperations[i];
      final isFirst = i == 0;

      wrappedOperations.add(_Operation<C, E>(
        (C context) async {
          // First operation evaluates the predicate
          if (isFirst) {
            shouldExecuteBranch = predicate(context);
          }

          // Skip if predicate was false
          if (shouldExecuteBranch == false) {
            return Right(context);
          }

          // Execute the operation
          return await op.execute(context);
        },
        // Only provide compensation if branch executed
        // The compensation will only be called if the operation executed successfully
        // We check shouldExecuteBranch inside the compensation wrapper
        op.compensate != null
            ? (C context) async {
                // Only compensate if branch was executed
                if (shouldExecuteBranch == true) {
                  await op.compensate!(context);
                }
              }
            : null,
      ));
    }

    return Railway([
      ..._operations,
      ...wrappedOperations,
    ]);
  }

  /// Executes the railway pipeline with the given initial context.
  ///
  /// Operations execute sequentially in the order they were added.
  /// Execution short-circuits on the first error, returning [Left] with the error.
  /// If all operations succeed, returns [Right] with the final context.
  ///
  /// When a failure occurs, compensation operations execute in reverse order (LIFO)
  /// for all successfully completed steps. Compensation errors are suppressed,
  /// and the original error is always returned.
  ///
  /// For an empty railway (no operations), returns [Right] with the initial context.
  Future<Either<E, C>> run(C initial) async {
    Either<E, C> current = Right(initial);

    // Track compensations with their captured contexts
    final compensationStack = <({Future<void> Function(C) compensate, C context})>[];

    for (final operation in _operations) {
      if (current.isLeft) break;

      final context = current.right;
      current = await operation.execute(context);

      // If execution succeeded and operation has compensation, add to stack
      // Capture the context AFTER execution for compensation
      if (current.isRight && operation.compensate != null) {
        compensationStack.add((
          compensate: operation.compensate!,
          context: current.right, // Context after this step executed
        ));
      }

      // If execution failed, run compensations in reverse order
      if (current.isLeft) {
        for (final entry in compensationStack.reversed) {
          try {
            await entry.compensate(entry.context);
          } catch (_) {
            // Suppress compensation errors - original error takes priority
            // TODO: Consider logging compensation failures
          }
        }
        // Return the original error
        break;
      }
    }

    return current;
  }
}
