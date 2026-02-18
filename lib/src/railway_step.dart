import 'package:either_dart/either.dart';

/// A state mutation operation in a railway pipeline.
///
/// Steps perform state changes and return an updated context.
/// They return [Right] with updated context on success or [Left] with an error.
///
/// Steps can optionally define compensation (cleanup/undo) operations via the
/// [compensate] method. When a pipeline fails, compensations execute in reverse
/// order (LIFO) for all successfully completed steps.
///
/// Type parameters:
/// - [E]: The error type to return on failure
/// - [C]: The context type to mutate and return
abstract class RailwayStep<E, C> {
  /// Executes the step and returns either an error or updated context.
  ///
  /// Returns [Right] with the updated context if the step succeeds.
  /// Returns [Left] with an error if the step fails.
  ///
  /// The step should use immutable context updates (e.g., copyWith pattern)
  /// rather than mutating the input context.
  Future<Either<E, C>> run(C context);

  /// Compensates (undoes/cleans up) the effects of this step.
  ///
  /// Called when a later operation in the pipeline fails, allowing this step
  /// to rollback or clean up any state changes it made. Compensations execute
  /// in reverse order (LIFO) - the most recently executed step compensates first.
  ///
  /// The [context] parameter is the context that was current when this step
  /// executed, allowing accurate cleanup based on the state at execution time.
  ///
  /// Compensation is best-effort cleanup, not a transactional guarantee:
  /// - Errors during compensation are suppressed and logged
  /// - The original pipeline error is always returned to the caller
  /// - Compensations should be designed to be idempotent where possible
  /// - Guards are never compensated (they are read-only)
  ///
  /// Steps that don't require cleanup can rely on the default empty implementation.
  ///
  /// Example:
  /// ```dart
  /// class CreateUserStep extends RailwayStep<MyError, MyContext> {
  ///   @override
  ///   Future<Either<MyError, MyContext>> run(MyContext context) async {
  ///     final user = await api.createUser(context.userData);
  ///     return Right(context.copyWith(userId: user.id));
  ///   }
  ///
  ///   @override
  ///   Future<void> compensate(MyContext context) async {
  ///     // Rollback: delete the user we created
  ///     if (context.userId != null) {
  ///       await api.deleteUser(context.userId);
  ///     }
  ///   }
  /// }
  /// ```
  Future<void> compensate(C context) async {
    // Default: no compensation needed
  }
}
