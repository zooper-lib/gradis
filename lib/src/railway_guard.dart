import 'package:either_dart/either.dart';

/// A validation operation in a railway pipeline.
///
/// Guards perform read-only validation without mutating the context.
/// They return [Right] on successful validation or [Left] with an error.
///
/// Type parameters:
/// - [C]: The context type to validate
/// - [E]: The error type to return on validation failure
abstract interface class RailwayGuard<C, E> {
  /// Validates the context and returns either an error or success.
  ///
  /// Returns [Right] with null/void if validation succeeds.
  /// Returns [Left] with an error if validation fails.
  ///
  /// The guard must not modify the context - it is read-only validation.
  Future<Either<E, void>> check(C context);
}
