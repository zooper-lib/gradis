part of 'railway.dart';

/// Internal data structure representing a single switch case.
///
/// Each case can match either by value equality or by a predicate function.
class _SwitchCase<E, C, T> {
  /// Optional value to match against (for `when()` cases).
  final T? matchValue;

  /// Optional predicate to evaluate (for `whenMatch()` cases).
  final bool Function(T)? predicate;

  /// Builder function to construct the railway for this case.
  final Railway<E, C> Function(Railway<E, C>) builder;

  /// Creates a value-based switch case.
  _SwitchCase.value(this.matchValue, this.builder) : predicate = null;

  /// Creates a predicate-based switch case.
  _SwitchCase.predicate(this.predicate, this.builder) : matchValue = null;

  /// Checks if this case matches the given selector output.
  bool matches(T selectorOutput) {
    if (predicate != null) {
      return predicate!(selectorOutput);
    } else {
      return matchValue == selectorOutput;
    }
  }
}

/// A fluent builder for declarative switch/case routing in a railway pipeline.
///
/// Created by calling [Railway.switchOn] with a selector function. Allows
/// defining multiple cases with [when] (value equality) or [whenMatch]
/// (predicate), and an optional fallback with [otherwise].
///
/// The switch evaluates the selector function once, checks cases in order,
/// and executes only the first matching case. All operations from the matched
/// case are added to the main railway's operation list and participate in
/// compensation.
///
/// Type parameters:
/// - [E]: The error type for the railway
/// - [C]: The context type flowing through the railway
/// - [T]: The type returned by the selector function
final class SwitchBuilder<E, C, T> {
  /// The selector function to evaluate once per switch execution.
  final T Function(C) _selector;

  /// List of cases to check in order.
  final List<_SwitchCase<E, C, T>> _cases;

  /// Optional fallback builder when no cases match.
  final Railway<E, C> Function(Railway<E, C>)? _otherwise;

  /// Reference to the parent railway to add operations to.
  final Railway<E, C> _railway;

  /// Creates a switch builder with the given selector and parent railway.
  const SwitchBuilder._internal(
    this._railway,
    this._selector,
    this._cases,
    this._otherwise,
  );

  /// Creates an initial switch builder from a railway and selector.
  factory SwitchBuilder.create(Railway<E, C> railway, T Function(C) selector) {
    return SwitchBuilder._internal(railway, selector, const [], null);
  }

  /// Adds a case that matches by value equality.
  ///
  /// When the switch executes, if the selector output equals [value]
  /// (using `==`), the [builder] function is executed to add operations
  /// to the railway.
  ///
  /// Cases are checked in the order they are added. The first matching
  /// case executes; subsequent cases are skipped (short-circuit).
  ///
  /// Example:
  /// ```dart
  /// Railway<MyError, MyContext>()
  ///   .switchOn((ctx) => ctx.status)
  ///     .when(Status.active, (r) => r.step(ProcessActive()))
  ///     .when(Status.inactive, (r) => r.step(ProcessInactive()))
  ///     .otherwise((r) => r.step(HandleUnknown()))
  /// ```
  SwitchBuilder<E, C, T> when(
    T value,
    Railway<E, C> Function(Railway<E, C>) builder,
  ) {
    return SwitchBuilder._internal(
      _railway,
      _selector,
      [..._cases, _SwitchCase.value(value, builder)],
      _otherwise,
    );
  }

  /// Adds a case that matches using a predicate function.
  ///
  /// When the switch executes, if [predicate] returns true for the
  /// selector output, the [builder] function is executed to add operations
  /// to the railway.
  ///
  /// This is useful for range matching, complex conditions, or any logic
  /// that can't be expressed as simple value equality.
  ///
  /// Cases are checked in the order they are added. The first matching
  /// case executes; subsequent cases are skipped (short-circuit).
  ///
  /// Example:
  /// ```dart
  /// Railway<MyError, MyContext>()
  ///   .switchOn((ctx) => ctx.age)
  ///     .whenMatch((age) => age >= 0 && age < 18, (r) => r.step(MinorFlow()))
  ///     .whenMatch((age) => age >= 18 && age < 65, (r) => r.step(AdultFlow()))
  ///     .whenMatch((age) => age >= 65, (r) => r.step(SeniorFlow()))
  ///     .end()
  /// ```
  SwitchBuilder<E, C, T> whenMatch(
    bool Function(T) predicate,
    Railway<E, C> Function(Railway<E, C>) builder,
  ) {
    return SwitchBuilder._internal(
      _railway,
      _selector,
      [..._cases, _SwitchCase.predicate(predicate, builder)],
      _otherwise,
    );
  }

  /// Terminates the switch with a fallback case and returns the railway.
  ///
  /// The [builder] is executed if no previous cases matched. This ensures
  /// that some action is always taken, even when the selector output doesn't
  /// match any defined cases.
  ///
  /// After calling [otherwise], the Railway is returned and you can continue
  /// chaining operations.
  ///
  /// Example:
  /// ```dart
  /// Railway<MyError, MyContext>()
  ///   .switchOn((ctx) => ctx.userType)
  ///     .when(UserType.admin, (r) => r.step(AdminFlow()))
  ///     .when(UserType.user, (r) => r.step(UserFlow()))
  ///     .otherwise((r) => r.step(DefaultFlow()))
  ///   .step(ContinueWorkflow())
  /// ```
  Railway<E, C> otherwise(Railway<E, C> Function(Railway<E, C>) builder) {
    // Create a new builder with the otherwise set, then finalize it
    final builderWithOtherwise = SwitchBuilder._internal(
      _railway,
      _selector,
      _cases,
      builder,
    );
    return builderWithOtherwise._finalize();
  }

  /// Terminates the switch without a fallback case and returns the railway.
  ///
  /// If no cases match during execution, the context passes through unchanged
  /// (no operations are added).
  ///
  /// Use this when you want conditional routing but don't need a catch-all case.
  ///
  /// Example:
  /// ```dart
  /// Railway<MyError, MyContext>()
  ///   .switchOn((ctx) => ctx.feature)
  ///     .when(Feature.premium, (r) => r.step(PremiumFeature()))
  ///     .when(Feature.beta, (r) => r.step(BetaFeature()))
  ///     .end()  // No fallback - passthrough if neither matches
  ///   .step(CommonStep())
  /// ```
  Railway<E, C> end() {
    return _finalize();
  }

  /// Internal method to finalize the switch and add it to the railway.
  Railway<E, C> _finalize() {
    // Pre-build all case railways to get their operations
    final List<List<_Operation<E, C>>> allCaseOperations = [];

    for (final switchCase in _cases) {
      final caseRailway = switchCase.builder(Railway<E, C>());
      allCaseOperations.add(caseRailway._operations);
    }

    // Pre-build otherwise railway if present
    final List<_Operation<E, C>>? otherwiseOperations = _otherwise != null ? _otherwise!(Railway<E, C>())._operations : null;

    // Create a single composite operation that handles the entire switch.
    // This maintains fresh state for each run and evaluates the selector once.
    final switchOp = _Operation<E, C>(
      (C entryContext) async {
        // Evaluate selector once with the entry context
        T selectorValue;
        try {
          selectorValue = _selector(entryContext);
        } catch (error) {
          // Selector error - pass through unchanged
          return Right(entryContext);
        }

        // Find first matching case
        int? matchedCaseIndex;
        for (var i = 0; i < _cases.length; i++) {
          if (_cases[i].matches(selectorValue)) {
            matchedCaseIndex = i;
            break;
          }
        }

        // Execute operations from matched case or otherwise
        C currentContext = entryContext;
        List<_Operation<E, C>>? opsToExecute;

        if (matchedCaseIndex != null) {
          opsToExecute = allCaseOperations[matchedCaseIndex];
        } else if (otherwiseOperations != null) {
          opsToExecute = otherwiseOperations;
        }

        if (opsToExecute != null) {
          // Track which operations executed successfully for compensation
          final executedOps = <_Operation<E, C>>[];

          for (final op in opsToExecute) {
            final result = await op.execute(currentContext);
            if (result.isLeft) {
              // Operation failed - compensate executed ops in reverse
              for (var i = executedOps.length - 1; i >= 0; i--) {
                final executedOp = executedOps[i];
                if (executedOp.compensate != null) {
                  try {
                    await executedOp.compensate!(currentContext);
                  } catch (_) {
                    // Best-effort compensation
                  }
                }
              }
              return result; // Propagate error
            }
            currentContext = result.right;
            executedOps.add(op);
          }
        }

        return Right(currentContext);
      },
      null, // Compensation is handled inline above
    );

    return Railway<E, C>([
      ..._railway._operations,
      switchOp,
    ]);
  }
}
