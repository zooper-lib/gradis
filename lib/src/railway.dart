import 'package:either_dart/either.dart';
import 'railway_guard.dart';
import 'railway_step.dart';

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
  final List<Future<Either<E, C>> Function(C)> _pipeline;

  /// Creates a new railway with an optional existing pipeline.
  ///
  /// The pipeline defaults to an empty list, creating a railway with no operations.
  const Railway([this._pipeline = const []]);

  /// Adds a guard to the railway pipeline.
  ///
  /// Returns a new [Railway] instance with the guard's check function appended.
  /// The original railway instance remains unchanged (immutable builder pattern).
  ///
  /// Guards perform read-only validation and do not modify the context.
  Railway<C, E> guard(RailwayGuard<C, E> guard) {
    return Railway([
      ..._pipeline,
      (C context) async {
        final result = await guard.check(context);
        return result.fold(
          (error) => Left(error),
          (_) => Right(context),
        );
      },
    ]);
  }

  /// Adds a step to the railway pipeline.
  ///
  /// Returns a new [Railway] instance with the step's run function appended.
  /// The original railway instance remains unchanged (immutable builder pattern).
  ///
  /// Steps perform state mutation and return an updated context.
  Railway<C, E> step(RailwayStep<C, E> step) {
    return Railway([..._pipeline, step.run]);
  }

  /// Executes the railway pipeline with the given initial context.
  ///
  /// Operations execute sequentially in the order they were added.
  /// Execution short-circuits on the first error, returning [Left] with the error.
  /// If all operations succeed, returns [Right] with the final context.
  ///
  /// For an empty railway (no operations), returns [Right] with the initial context.
  Future<Either<E, C>> run(C initial) async {
    Either<E, C> current = Right(initial);

    for (final operation in _pipeline) {
      if (current.isLeft) break;

      final context = current.right;
      current = await operation(context);
    }

    return current;
  }
}
