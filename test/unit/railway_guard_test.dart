import 'package:either_dart/either.dart';
import 'package:gradis/gradis.dart';
import 'package:test/test.dart';

// Test context
final class TestContext {
  final String value;
  final int callCount;

  const TestContext(this.value, {this.callCount = 0});

  TestContext copyWith({String? value, int? callCount}) {
    return TestContext(
      value ?? this.value,
      callCount: callCount ?? this.callCount,
    );
  }
}

// Test error type
enum TestError { guardFailed, otherError }

// Test guard that tracks context
class ContextCheckGuard implements RailwayGuard<TestContext, TestError> {
  final String expectedValue;
  String? receivedValue;

  ContextCheckGuard(this.expectedValue);

  @override
  Future<Either<TestError, void>> check(TestContext context) async {
    receivedValue = context.value;
    if (context.value == expectedValue) {
      return const Right(null);
    }
    return const Left(TestError.guardFailed);
  }
}

// Successful guard
class SuccessGuard implements RailwayGuard<TestContext, TestError> {
  @override
  Future<Either<TestError, void>> check(TestContext context) async {
    return const Right(null);
  }
}

// Failing guard
class FailGuard implements RailwayGuard<TestContext, TestError> {
  @override
  Future<Either<TestError, void>> check(TestContext context) async {
    return const Left(TestError.guardFailed);
  }
}

// Counter guard to track execution
class CounterGuard implements RailwayGuard<TestContext, TestError> {
  int executionCount = 0;

  @override
  Future<Either<TestError, void>> check(TestContext context) async {
    executionCount++;
    return const Right(null);
  }
}

void main() {
  group('RailwayGuard Interface', () {
    test('guard check() receives correct context', () async {
      final guard = ContextCheckGuard('test-value');
      final context = const TestContext('test-value');

      await guard.check(context);

      expect(guard.receivedValue, equals('test-value'));
    });

    test('successful guard returns Right(null)', () async {
      final guard = SuccessGuard();
      final context = const TestContext('any-value');

      final result = await guard.check(context);

      expect(result.isRight, isTrue);
    });

    test('failed guard returns Left(error)', () async {
      final guard = FailGuard();
      final context = const TestContext('any-value');

      final result = await guard.check(context);

      expect(result.isLeft, isTrue);
      expect(result.left, equals(TestError.guardFailed));
    });

    test('guard cannot mutate context (verify immutability)', () async {
      final guard = SuccessGuard();
      const originalContext = TestContext('original');

      await guard.check(originalContext);

      // Context should remain unchanged
      expect(originalContext.value, equals('original'));
    });

    test('multiple guards execute sequentially', () async {
      final guard1 = CounterGuard();
      final guard2 = CounterGuard();
      final guard3 = CounterGuard();

      final railway = const Railway<TestContext, TestError>().guard(guard1).guard(guard2).guard(guard3);

      await railway.run(const TestContext('test'));

      expect(guard1.executionCount, equals(1));
      expect(guard2.executionCount, equals(1));
      expect(guard3.executionCount, equals(1));
    });

    test('first guard failure short-circuits remaining guards', () async {
      final guard1 = CounterGuard();
      final guard2 = FailGuard();
      final guard3 = CounterGuard();

      final railway = const Railway<TestContext, TestError>().guard(guard1).guard(guard2).guard(guard3);

      final result = await railway.run(const TestContext('test'));

      expect(result.isLeft, isTrue);
      expect(guard1.executionCount, equals(1));
      expect(guard3.executionCount, equals(0)); // Should not execute
    });
  });
}
