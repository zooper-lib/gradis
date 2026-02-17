import 'package:either_dart/either.dart';
import 'package:gradis/gradis.dart';
import 'package:test/test.dart';

// Test context
final class TestContext {
  final String data;
  final int counter;

  const TestContext({required this.data, this.counter = 0});

  TestContext copyWith({String? data, int? counter}) {
    return TestContext(
      data: data ?? this.data,
      counter: counter ?? this.counter,
    );
  }
}

// Test error type
enum TestError { stepFailed, repositoryError }

// Step that verifies received context
class ContextCheckStep implements RailwayStep<TestContext, TestError> {
  final String expectedData;
  String? receivedData;

  ContextCheckStep(this.expectedData);

  @override
  Future<Either<TestError, TestContext>> run(TestContext context) async {
    receivedData = context.data;
    if (context.data == expectedData) {
      return Right(context.copyWith(counter: context.counter + 1));
    }
    return const Left(TestError.stepFailed);
  }
}

// Successful step that updates context
class IncrementStep implements RailwayStep<TestContext, TestError> {
  final int incrementBy;

  const IncrementStep({this.incrementBy = 1});

  @override
  Future<Either<TestError, TestContext>> run(TestContext context) async {
    return Right(context.copyWith(counter: context.counter + incrementBy));
  }
}

// Failing step
class FailStep implements RailwayStep<TestContext, TestError> {
  @override
  Future<Either<TestError, TestContext>> run(TestContext context) async {
    return const Left(TestError.stepFailed);
  }
}

// Step with side effects (mock repository)
class RepositoryStep implements RailwayStep<TestContext, TestError> {
  final MockRepository repository;

  const RepositoryStep(this.repository);

  @override
  Future<Either<TestError, TestContext>> run(TestContext context) async {
    final saved = await repository.save(context.data);
    if (saved) {
      return Right(context.copyWith(data: '${context.data}-saved'));
    }
    return const Left(TestError.repositoryError);
  }
}

// Mock repository
class MockRepository {
  final bool shouldFail;
  final List<String> savedItems = [];

  MockRepository({this.shouldFail = false});

  Future<bool> save(String data) async {
    if (shouldFail) return false;
    savedItems.add(data);
    return true;
  }
}

void main() {
  group('RailwayStep Interface', () {
    test('step run() receives correct context', () async {
      final step = ContextCheckStep('test-data');
      final context = const TestContext(data: 'test-data');

      await step.run(context);

      expect(step.receivedData, equals('test-data'));
    });

    test('successful step returns Right(updated context)', () async {
      final step = const IncrementStep(incrementBy: 5);
      final context = const TestContext(data: 'test', counter: 10);

      final result = await step.run(context);

      expect(result.isRight, isTrue);
      expect(result.right.counter, equals(15));
      expect(result.right.data, equals('test')); // Unchanged field preserved
    });

    test('failed step returns Left(error)', () async {
      final step = FailStep();
      final context = const TestContext(data: 'test');

      final result = await step.run(context);

      expect(result.isLeft, isTrue);
      expect(result.left, equals(TestError.stepFailed));
    });

    test('context accumulation across multiple steps', () async {
      final railway = const Railway<TestContext, TestError>()
          .step(const IncrementStep(incrementBy: 10))
          .step(const IncrementStep(incrementBy: 5))
          .step(const IncrementStep(incrementBy: 3));

      final result = await railway.run(const TestContext(data: 'test'));

      expect(result.isRight, isTrue);
      expect(result.right.counter, equals(18)); // 0 + 10 + 5 + 3
    });

    test('step failure short-circuits remaining steps', () async {
      final railway =
          const Railway<TestContext, TestError>().step(const IncrementStep(incrementBy: 10)).step(FailStep()).step(const IncrementStep(incrementBy: 5));

      final result = await railway.run(const TestContext(data: 'test'));

      expect(result.isLeft, isTrue);
      expect(result.left, equals(TestError.stepFailed));
    });

    test('steps can perform side effects (mock repository)', () async {
      final repository = MockRepository();
      final step = RepositoryStep(repository);
      final context = const TestContext(data: 'test-item');

      final result = await step.run(context);

      expect(result.isRight, isTrue);
      expect(repository.savedItems, contains('test-item'));
      expect(result.right.data, equals('test-item-saved'));
    });
  });
}
