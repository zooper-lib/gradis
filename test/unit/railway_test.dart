import 'package:either_dart/either.dart';
import 'package:gradis/gradis.dart';
import 'package:test/test.dart';

// Test context
final class TestContext {
  final int value;
  const TestContext(this.value);

  TestContext copyWith({int? value}) {
    return TestContext(value ?? this.value);
  }
}

// Test error type
enum TestError { guardFailed, stepFailed }

// Test guard
class TestGuard implements RailwayGuard<TestContext, TestError> {
  final bool shouldFail;
  const TestGuard({this.shouldFail = false});

  @override
  Future<Either<TestError, void>> check(TestContext context) async {
    if (shouldFail) {
      return const Left(TestError.guardFailed);
    }
    return const Right(null);
  }
}

// Test step
class TestStep implements RailwayStep<TestContext, TestError> {
  final int increment;
  final bool shouldFail;

  const TestStep({this.increment = 1, this.shouldFail = false});

  @override
  Future<Either<TestError, TestContext>> run(TestContext context) async {
    if (shouldFail) {
      return const Left(TestError.stepFailed);
    }
    return Right(context.copyWith(value: context.value + increment));
  }
}

void main() {
  group('Railway Builder', () {
    test('creating empty railway instance', () {
      final railway = const Railway<TestContext, TestError>();
      expect(railway, isNotNull);
    });

    test('guard() returns new immutable instance', () {
      final railway1 = const Railway<TestContext, TestError>();
      final railway2 = railway1.guard(const TestGuard());

      expect(railway1, isNot(same(railway2)));
    });

    test('step() returns new immutable instance', () {
      final railway1 = const Railway<TestContext, TestError>();
      final railway2 = railway1.step(const TestStep());

      expect(railway1, isNot(same(railway2)));
    });

    test('chaining multiple guards and steps preserves order', () async {
      final railway = const Railway<TestContext, TestError>()
          .guard(const TestGuard())
          .guard(const TestGuard())
          .step(const TestStep(increment: 10))
          .step(const TestStep(increment: 5));

      final result = await railway.run(const TestContext(0));

      expect(result.isRight, isTrue);
      expect(result.right.value, equals(15)); // 0 + 10 + 5
    });

    test('original railway unchanged after builder calls', () async {
      final railway1 = const Railway<TestContext, TestError>();
      railway1.guard(const TestGuard());
      railway1.step(const TestStep());

      // Original railway should still be empty
      final result = await railway1.run(const TestContext(42));
      expect(result.isRight, isTrue);
      expect(result.right.value, equals(42)); // Unchanged
    });

    test('type safety with context and error types', () {
      // This test verifies compile-time type safety
      // If this compiles, the type constraints are working correctly
      final railway = const Railway<TestContext, TestError>().guard(const TestGuard()).step(const TestStep());

      expect(railway, isA<Railway<TestContext, TestError>>());
    });
  });
}
