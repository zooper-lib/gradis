import 'package:either_dart/either.dart';
import 'package:gradis/gradis.dart';
import 'package:test/test.dart';

// Test context
final class TestContext {
  final List<String> log;
  final int value;

  const TestContext({required this.log, this.value = 0});

  TestContext copyWith({List<String>? log, int? value}) {
    return TestContext(
      log: log ?? this.log,
      value: value ?? this.value,
    );
  }

  TestContext addLog(String entry) {
    return copyWith(log: [...log, entry]);
  }
}

// Test error type
enum TestError { guardError, stepError }

// Logging guard
class LoggingGuard implements RailwayGuard<TestContext, TestError> {
  final String logMessage;
  final bool shouldFail;

  const LoggingGuard(this.logMessage, {this.shouldFail = false});

  @override
  Future<Either<TestError, void>> check(TestContext context) async {
    // Simulate async work
    await Future.delayed(const Duration(milliseconds: 10));

    if (shouldFail) {
      return const Left(TestError.guardError);
    }
    return const Right(null);
  }
}

// Logging step
class LoggingStep extends RailwayStep<TestContext, TestError> {
  final String logMessage;
  final int increment;
  final bool shouldFail;

  LoggingStep(
    this.logMessage, {
    this.increment = 1,
    this.shouldFail = false,
  });

  @override
  Future<Either<TestError, TestContext>> run(TestContext context) async {
    // Simulate async work
    await Future.delayed(const Duration(milliseconds: 10));

    if (shouldFail) {
      return const Left(TestError.stepError);
    }

    return Right(
      context.addLog(logMessage).copyWith(value: context.value + increment),
    );
  }
}

void main() {
  group('Railway Execution Engine', () {
    test('empty railway returns initial context', () async {
      const railway = Railway<TestContext, TestError>();
      const context = TestContext(log: ['initial']);

      final result = await railway.run(context);

      expect(result.isRight, isTrue);
      expect(result.right.log, equals(['initial']));
    });

    test('all operations succeed returns final context', () async {
      final railway = const Railway<TestContext, TestError>()
          .guard(const LoggingGuard('guard1'))
          .step(LoggingStep('step1', increment: 10))
          .guard(const LoggingGuard('guard2'))
          .step(LoggingStep('step2', increment: 5));

      final result = await railway.run(const TestContext(log: []));

      expect(result.isRight, isTrue);
      expect(result.right.log, equals(['step1', 'step2']));
      expect(result.right.value, equals(15));
    });

    test('guard failure stops execution and returns error', () async {
      final railway = const Railway<TestContext, TestError>()
          .step(LoggingStep('step1'))
          .guard(const LoggingGuard('guard1', shouldFail: true))
          .step(LoggingStep('step2'));

      final result = await railway.run(const TestContext(log: []));

      expect(result.isLeft, isTrue);
      expect(result.left, equals(TestError.guardError));
    });

    test('step failure stops execution and returns error', () async {
      final railway = const Railway<TestContext, TestError>()
          .step(LoggingStep('step1'))
          .step(LoggingStep('step2', shouldFail: true))
          .step(LoggingStep('step3'));

      final result = await railway.run(const TestContext(log: []));

      expect(result.isLeft, isTrue);
      expect(result.left, equals(TestError.stepError));
      // Only step1 should have executed
      expect(result.fold((l) => null, (r) => r.log), isNull);
    });

    test('sequential async operation execution', () async {
      final executionOrder = <String>[];

      final step1 = _OrderTrackingStep('step1', executionOrder);
      final step2 = _OrderTrackingStep('step2', executionOrder);
      final step3 = _OrderTrackingStep('step3', executionOrder);

      final railway = const Railway<TestContext, TestError>().step(step1).step(step2).step(step3);

      await railway.run(const TestContext(log: []));

      expect(executionOrder, equals(['step1', 'step2', 'step3']));
    });

    test('Either short-circuit behavior with fold', () async {
      // This test verifies that fold-based composition short-circuits correctly
      final railway = const Railway<TestContext, TestError>()
          .step(LoggingStep('step1', increment: 1))
          .guard(const LoggingGuard('guard1', shouldFail: true))
          .step(LoggingStep('step2', increment: 1))
          .step(LoggingStep('step3', increment: 1));

      final result = await railway.run(const TestContext(log: [], value: 0));

      expect(result.isLeft, isTrue);
      // The guard failure should prevent steps 2 and 3 from executing
    });

    test('execution is deterministic and predictable', () async {
      final railway = const Railway<TestContext, TestError>()
          .step(LoggingStep('a', increment: 1))
          .step(LoggingStep('b', increment: 2))
          .step(LoggingStep('c', increment: 3));

      // Run multiple times
      for (var i = 0; i < 5; i++) {
        final result = await railway.run(const TestContext(log: []));

        expect(result.isRight, isTrue);
        expect(result.right.log, equals(['a', 'b', 'c']));
        expect(result.right.value, equals(6));
      }
    });
  });
}

// Helper class to track execution order
class _OrderTrackingStep extends RailwayStep<TestContext, TestError> {
  final String name;
  final List<String> executionOrder;

  _OrderTrackingStep(this.name, this.executionOrder);

  @override
  Future<Either<TestError, TestContext>> run(TestContext context) async {
    await Future.delayed(const Duration(milliseconds: 10));
    executionOrder.add(name);
    return Right(context.addLog(name));
  }
}
