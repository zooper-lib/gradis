import 'package:either_dart/either.dart';
import 'package:gradis/src/railway.dart';
import 'package:gradis/src/railway_guard.dart';
import 'package:gradis/src/railway_step.dart';
import 'package:test/test.dart';

// Test context
class TestContext {
  final int value;
  final bool isAdmin;
  final List<String> log;

  const TestContext({
    this.value = 0,
    this.isAdmin = false,
    this.log = const [],
  });

  TestContext copyWith({int? value, bool? isAdmin, List<String>? log}) {
    return TestContext(
      value: value ?? this.value,
      isAdmin: isAdmin ?? this.isAdmin,
      log: log ?? this.log,
    );
  }

  TestContext addLog(String message) {
    return copyWith(log: [...log, message]);
  }
}

// Test error
enum TestError { stepFailed, guardFailed }

// Step for testing
class TestStep extends RailwayStep<TestError, TestContext> {
  final String name;
  final int increment;
  final bool shouldFail;
  final List<String>? compensationLog;

  TestStep(
    this.name, {
    this.increment = 1,
    this.shouldFail = false,
    this.compensationLog,
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
    compensationLog?.add('compensate:$name');
  }
}

// Guard for testing
class TestGuard implements RailwayGuard<TestError, TestContext> {
  final String name;
  final bool shouldFail;
  final List<String>? executionLog;

  TestGuard(this.name, {this.shouldFail = false, this.executionLog});

  @override
  Future<Either<TestError, void>> check(TestContext context) async {
    executionLog?.add('guard:$name');
    if (shouldFail) {
      return const Left(TestError.guardFailed);
    }
    return const Right(null);
  }
}

void main() {
  group('Railway Branch', () {
    test('branch with true predicate executes sub-pipeline', () async {
      final railway = const Railway<TestError, TestContext>()
          .step(TestStep('before'))
          .branch(
            (ctx) => ctx.isAdmin,
            (r) => r.step(TestStep('admin')),
          )
          .step(TestStep('after'));

      final result = await railway.run(const TestContext(isAdmin: true));

      expect(result.isRight, true);
      expect(result.right.log, ['execute:before', 'execute:admin', 'execute:after']);
    });

    test('branch with false predicate skips sub-pipeline', () async {
      final railway = const Railway<TestError, TestContext>()
          .step(TestStep('before'))
          .branch(
            (ctx) => ctx.isAdmin,
            (r) => r.step(TestStep('admin')),
          )
          .step(TestStep('after'));

      final result = await railway.run(const TestContext(isAdmin: false));

      expect(result.isRight, true);
      expect(result.right.log, ['execute:before', 'execute:after']);
      expect(result.right.log.contains('execute:admin'), false);
    });

    test('branch step compensations execute on later failure', () async {
      final compensationLog = <String>[];

      final railway = const Railway<TestError, TestContext>()
          .step(TestStep('step1', compensationLog: compensationLog))
          .branch(
            (ctx) => ctx.isAdmin,
            (r) => r.step(TestStep('branch-step', compensationLog: compensationLog)),
          )
          .step(TestStep('step2', shouldFail: true, compensationLog: compensationLog));

      final result = await railway.run(const TestContext(isAdmin: true));

      expect(result.isLeft, true);
      expect(compensationLog, containsAll(['compensate:branch-step', 'compensate:step1']));
    });

    test('skipped branch has no compensations', () async {
      final compensationLog = <String>[];

      final railway = const Railway<TestError, TestContext>()
          .step(TestStep('step1', compensationLog: compensationLog))
          .branch(
            (ctx) => ctx.isAdmin,
            (r) => r.step(TestStep('branch-step', compensationLog: compensationLog)),
          )
          .step(TestStep('step2', shouldFail: true, compensationLog: compensationLog));

      final result = await railway.run(const TestContext(isAdmin: false));

      expect(result.isLeft, true);
      expect(compensationLog, ['compensate:step1']);
      expect(compensationLog.contains('compensate:branch-step'), false);
    });

    test('branch step failure propagates to main pipeline', () async {
      final railway = const Railway<TestError, TestContext>()
          .step(TestStep('before'))
          .branch(
            (ctx) => ctx.isAdmin,
            (r) => r.step(TestStep('branch-step', shouldFail: true)),
          )
          .step(TestStep('after'));

      final result = await railway.run(const TestContext(isAdmin: true));

      expect(result.isLeft, true);
      expect(result.left, TestError.stepFailed);
    });

    test('branch guard failure propagates to main pipeline', () async {
      final railway = const Railway<TestError, TestContext>()
          .step(TestStep('before'))
          .branch(
            (ctx) => ctx.isAdmin,
            (r) => r.guard(TestGuard('branch-guard', shouldFail: true)),
          )
          .step(TestStep('after'));

      final result = await railway.run(const TestContext(isAdmin: true));

      expect(result.isLeft, true);
      expect(result.left, TestError.guardFailed);
    });

    test('nested branches execute correctly', () async {
      final railway = const Railway<TestError, TestContext>()
          .step(TestStep('step1'))
          .branch(
            (ctx) => ctx.value > 0,
            (r) => r.step(TestStep('outer-branch')).branch(
                  (ctx) => ctx.isAdmin,
                  (r2) => r2.step(TestStep('inner-branch')),
                ),
          )
          .step(TestStep('step2'));

      final result = await railway.run(const TestContext(isAdmin: true));

      expect(result.isRight, true);
      expect(
        result.right.log,
        ['execute:step1', 'execute:outer-branch', 'execute:inner-branch', 'execute:step2'],
      );
    });

    test('nested branch compensations execute in correct reverse order', () async {
      final compensationLog = <String>[];

      final railway = const Railway<TestError, TestContext>()
          .step(TestStep('step1', compensationLog: compensationLog))
          .branch(
            (ctx) => ctx.value > 0,
            (r) => r.step(TestStep('outer', compensationLog: compensationLog)).branch(
                  (ctx) => ctx.isAdmin,
                  (r2) => r2.step(TestStep('inner', compensationLog: compensationLog)),
                ),
          )
          .step(TestStep('failing-step', shouldFail: true, compensationLog: compensationLog));

      final result = await railway.run(const TestContext(isAdmin: true));

      expect(result.isLeft, true);
      // Compensations should be: inner, outer, step1 (reverse of execution order)
      expect(compensationLog, ['compensate:inner', 'compensate:outer', 'compensate:step1']);
    });

    test('branch maintains immutable builder pattern', () async {
      final railway1 = const Railway<TestError, TestContext>().step(TestStep('step1'));

      final railway2 = railway1.branch(
        (ctx) => ctx.isAdmin,
        (r) => r.step(TestStep('branch-step')),
      );

      expect(railway1, isNot(same(railway2)));

      // Railway1 should not have the branch
      final result1 = await railway1.run(const TestContext(isAdmin: true));
      expect(result1.right.log, ['execute:step1']);

      // Railway2 should have the branch
      final result2 = await railway2.run(const TestContext(isAdmin: true));
      expect(result2.right.log, ['execute:step1', 'execute:branch-step']);
    });
  });
}
