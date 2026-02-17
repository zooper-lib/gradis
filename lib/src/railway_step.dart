import 'package:either_dart/either.dart';

/// A state mutation operation in a railway pipeline.
///
/// Steps perform state changes and return an updated context.
/// They return [Right] with updated context on success or [Left] with an error.
///
/// Type parameters:
/// - [C]: The context type to mutate and return
/// - [E]: The error type to return on failure
abstract interface class RailwayStep<C, E> {
  /// Executes the step and returns either an error or updated context.
  ///
  /// Returns [Right] with the updated context if the step succeeds.
  /// Returns [Left] with an error if the step fails.
  ///
  /// The step should use immutable context updates (e.g., copyWith pattern)
  /// rather than mutating the input context.
  Future<Either<E, C>> run(C context);
}
