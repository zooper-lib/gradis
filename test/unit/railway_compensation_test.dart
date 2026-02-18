import 'package:either_dart/either.dart';
import 'package:gradis/src/railway.dart';
import 'package:gradis/src/railway_guard.dart';
import 'package:gradis/src/railway_step.dart';
import 'package:test/test.dart';

// Test context
class TestContext {
  final int value;
  final List<String> log;

  const TestContext({this.value = 0, this.log = const []});

  TestContext copyWith({int? value, List<String>? log}) {
    return TestContext(
      value: value ?? this.value,
      log: log ?? this.log,
    );
  }

  TestContext addLog(String message) {
    return copyWith(log: [...log, message]);
  }
}

// Test error
enum TestError { stepFailed, guardFailed }

// Step with compensation tracking
class CompensatingStep extends RailwayStep<TestError, TestContext> {
  final String name;
  final int increment;
  final bool shouldFail;

  CompensatingStep(
    this.name, {
    this.increment = 1,
    this.shouldFail = false,
  });

  @override
  Future<Either<TestError, TestContext>> run(TestContext context) async {
    if (shouldFail) {
      return const Left(TestError.stepFailed);
    }
    return Right(
      context.copyWith(value: context.value + increment).addLog('execute:$name'),
    );
  }

  @override
  Future<void> compensate(TestContext context) async {
    // Track compensation execution
    // Note: We can't modify context here, but in real scenarios you'd
    // perform cleanup like deleting resources, rolling back transactions, etc.
  }
}

// Step that tracks compensation in a mutable list (for testing)
class TrackingCompensatingStep extends RailwayStep<TestError, TestContext> {
  final String name;
  final int increment;
  final bool shouldFail;
  final List<String> compensationLog;
  final bool compensationShouldFail;

  TrackingCompensatingStep(
    this.name,
    this.compensationLog, {
    this.increment = 1,
    this.shouldFail = false,
    this.compensationShouldFail = false,
  });

  @override
  Future<Either<TestError, TestContext>> run(TestContext context) async {
    if (shouldFail) {
      return const Left(TestError.stepFailed);
    }
    return Right(
      context.copyWith(value: context.value + increment).addLog('execute:$name'),
    );
  }

  @override
  Future<void> compensate(TestContext context) async {
    if (compensationShouldFail) {
      throw Exception('Compensation failed for $name');
    }
    compensationLog.add('compensate:$name:${context.value}');
  }
}

// Guard for testing
class TestGuard implements RailwayGuard<TestError, TestContext> {
  final bool shouldFail;

  TestGuard({this.shouldFail = false});

  @override
  Future<Either<TestError, void>> check(TestContext context) async {
    if (shouldFail) {
      return const Left(TestError.guardFailed);
    }
    return const Right(null);
  }
}

void main() {
  group('Railway Compensation', () {
    test('step with compensation executes compensation on failure', () async {
      final compensationLog = <String>[];

      final railway = const Railway<TestError, TestContext>()
          .step(TrackingCompensatingStep('step1', compensationLog, increment: 10))
          .step(TrackingCompensatingStep('step2', compensationLog, shouldFail: true));

      final result = await railway.run(const TestContext());

      expect(result.isLeft, true);
      expect(result.left, TestError.stepFailed);
      expect(compensationLog, ['compensate:step1:10']);
    });

    test('multiple steps with compensations execute in reverse order', () async {
      final compensationLog = <String>[];

      final railway = const Railway<TestError, TestContext>()
          .step(TrackingCompensatingStep('step1', compensationLog, increment: 5))
          .step(TrackingCompensatingStep('step2', compensationLog, increment: 10))
          .step(TrackingCompensatingStep('step3', compensationLog, increment: 3))
          .step(TrackingCompensatingStep('step4', compensationLog, shouldFail: true));

      final result = await railway.run(const TestContext());

      expect(result.isLeft, true);
      expect(compensationLog, [
        'compensate:step3:18', // value was 18 when step3 executed (5+10+3)
        'compensate:step2:15', // value was 15 when step2 executed (5+10)
        'compensate:step1:5', // value was 5 when step1 executed
      ]);
    });

    test('early failure prevents later step compensations', () async {
      final compensationLog = <String>[];

      final railway = const Railway<TestError, TestContext>()
          .step(TrackingCompensatingStep('step1', compensationLog, increment: 10))
          .step(TrackingCompensatingStep('step2', compensationLog, shouldFail: true))
          .step(TrackingCompensatingStep('step3', compensationLog, increment: 5));

      final result = await railway.run(const TestContext());

      expect(result.isLeft, true);
      // Only step1 should compensate; step3 never executed
      expect(compensationLog, ['compensate:step1:10']);
    });

    test('successful pipeline does not execute compensations', () async {
      final compensationLog = <String>[];

      final railway = const Railway<TestError, TestContext>()
          .step(TrackingCompensatingStep('step1', compensationLog, increment: 10))
          .step(TrackingCompensatingStep('step2', compensationLog, increment: 5));

      final result = await railway.run(const TestContext());

      expect(result.isRight, true);
      expect(result.right.value, 15);
      expect(compensationLog, isEmpty);
    });

    test('compensation receives correct captured context', () async {
      final compensationLog = <String>[];

      // Step1 executes with value=0, sets it to 10
      // Step2 executes with value=10, sets it to 20
      // Step3 fails
      // Compensation for step2 should receive context with value=10 (when it executed)
      // Compensation for step1 should receive context with value=0 (when it executed)
      final railway = const Railway<TestError, TestContext>()
          .step(TrackingCompensatingStep('step1', compensationLog, increment: 10))
          .step(TrackingCompensatingStep('step2', compensationLog, increment: 10))
          .step(TrackingCompensatingStep('step3', compensationLog, shouldFail: true));

      await railway.run(const TestContext());

      // Check that compensations received the context from when they executed
      expect(compensationLog, [
        'compensate:step2:20', // step2 saw value=10, incremented to 20
        'compensate:step1:10', // step1 saw value=0, incremented to 10
      ]);
    });

    test('compensation error is suppressed and original error returned', () async {
      final compensationLog = <String>[];

      final railway = const Railway<TestError, TestContext>()
          .step(TrackingCompensatingStep(
            'step1',
            compensationLog,
            increment: 10,
            compensationShouldFail: true,
          ))
          .step(TrackingCompensatingStep('step2', compensationLog, shouldFail: true));

      final result = await railway.run(const TestContext());

      expect(result.isLeft, true);
      expect(result.left, TestError.stepFailed); // Original error, not compensation error
    });

    test('multiple compensation failures do not stop cleanup', () async {
      final compensationLog = <String>[];

      final railway = const Railway<TestError, TestContext>()
          .step(TrackingCompensatingStep(
            'step1',
            compensationLog,
            increment: 5,
            compensationShouldFail: true,
          ))
          .step(TrackingCompensatingStep('step2', compensationLog, increment: 10))
          .step(TrackingCompensatingStep(
            'step3',
            compensationLog,
            increment: 3,
            compensationShouldFail: true,
          ))
          .step(TrackingCompensatingStep('step4', compensationLog, shouldFail: true));

      final result = await railway.run(const TestContext());

      expect(result.isLeft, true);
      // All compensations should attempt, even though step3 and step1 fail
      // step2 should succeed
      expect(compensationLog.contains('compensate:step2:15'), true);
    });

    test('guards are excluded from compensation', () async {
      final compensationLog = <String>[];

      final railway = const Railway<TestError, TestContext>()
          .guard(TestGuard())
          .step(TrackingCompensatingStep('step1', compensationLog, increment: 10))
          .guard(TestGuard())
          .step(TrackingCompensatingStep('step2', compensationLog, shouldFail: true));

      final result = await railway.run(const TestContext());

      expect(result.isLeft, true);
      // Only step1 should compensate, guards should not appear
      expect(compensationLog, ['compensate:step1:10']);
    });

    test('guard failure before steps results in no compensations', () async {
      final compensationLog = <String>[];

      final railway =
          const Railway<TestError, TestContext>().guard(TestGuard(shouldFail: true)).step(TrackingCompensatingStep('step1', compensationLog, increment: 10));

      final result = await railway.run(const TestContext());

      expect(result.isLeft, true);
      expect(result.left, TestError.guardFailed);
      expect(compensationLog, isEmpty); // No steps executed, so no compensations
    });
  });
}
