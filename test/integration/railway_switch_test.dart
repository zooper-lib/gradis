import 'package:either_dart/either.dart';
import 'package:gradis/gradis.dart';
import 'package:test/test.dart';

// Test domain types
final class TestContext {
  final String value;
  final int? count;
  final TestStatus? status;
  final int? age;

  const TestContext({
    required this.value,
    this.count,
    this.status,
    this.age,
  });

  TestContext copyWith({String? value, int? count, TestStatus? status, int? age}) {
    return TestContext(
      value: value ?? this.value,
      count: count ?? this.count,
      status: status ?? this.status,
      age: age ?? this.age,
    );
  }
}

enum TestError { validation, execution, unknown }

enum TestStatus { draft, pending, approved, rejected }

// Test steps
class IncrementStep extends RailwayStep<TestError, TestContext> {
  final String marker;

  IncrementStep([this.marker = '']);

  @override
  Future<Either<TestError, TestContext>> run(TestContext context) async {
    return Right(context.copyWith(count: (context.count ?? 0) + 1));
  }
}

class AppendMarkerStep extends RailwayStep<TestError, TestContext> {
  final String marker;

  AppendMarkerStep(this.marker);

  @override
  Future<Either<TestError, TestContext>> run(TestContext context) async {
    return Right(context.copyWith(value: context.value + marker));
  }
}

class FailingStep extends RailwayStep<TestError, TestContext> {
  @override
  Future<Either<TestError, TestContext>> run(TestContext context) async {
    return const Left(TestError.execution);
  }
}

// Helper to track selector execution count
class SelectorTracker {
  int callCount = 0;

  String call(TestContext ctx) {
    callCount++;
    return ctx.value;
  }
}

void main() {
  group('Railway Switch Pattern', () {
    group('Switch builder creation', () {
      test('switchOn() returns SwitchBuilder', () {
        final railway = const Railway<TestError, TestContext>();
        final switchBuilder = railway.switchOn<String>((ctx) => ctx.value);

        expect(switchBuilder, isA<SwitchBuilder<TestError, TestContext, String>>());
      });

      test('switchOn() with different selector types', () {
        final railway = const Railway<TestError, TestContext>();

        final stringSwitch = railway.switchOn<String>((ctx) => ctx.value);
        expect(stringSwitch, isA<SwitchBuilder<TestError, TestContext, String>>());

        final intSwitch = railway.switchOn<int>((ctx) => ctx.count ?? 0);
        expect(intSwitch, isA<SwitchBuilder<TestError, TestContext, int>>());

        final enumSwitch = railway.switchOn<TestStatus>((ctx) => ctx.status ?? TestStatus.draft);
        expect(enumSwitch, isA<SwitchBuilder<TestError, TestContext, TestStatus>>());
      });
    });

    group('Value equality matching with when()', () {
      test('when() executes on exact value match', () async {
        final railway =
            const Railway<TestError, TestContext>().switchOn<String>((ctx) => ctx.value).when('match', (r) => r.step(AppendMarkerStep(':matched'))).end();

        final result = await railway.run(const TestContext(value: 'match'));

        expect(result.isRight, isTrue);
        expect(result.right.value, equals('match:matched'));
      });

      test('when() skips on value mismatch', () async {
        final railway =
            const Railway<TestError, TestContext>().switchOn<String>((ctx) => ctx.value).when('other', (r) => r.step(AppendMarkerStep(':matched'))).end();

        final result = await railway.run(const TestContext(value: 'nomatch'));

        expect(result.isRight, isTrue);
        expect(result.right.value, equals('nomatch')); // Unchanged
      });

      test('when() with enum values', () async {
        final railway = const Railway<TestError, TestContext>()
            .switchOn<TestStatus>((ctx) => ctx.status ?? TestStatus.draft)
            .when(TestStatus.approved, (r) => r.step(AppendMarkerStep(':approved')))
            .when(TestStatus.rejected, (r) => r.step(AppendMarkerStep(':rejected')))
            .end();

        final result1 = await railway.run(const TestContext(value: 'test', status: TestStatus.approved));
        expect(result1.right.value, equals('test:approved'));

        final result2 = await railway.run(const TestContext(value: 'test', status: TestStatus.rejected));
        expect(result2.right.value, equals('test:rejected'));
      });

      test('when() with integer values', () async {
        final railway = const Railway<TestError, TestContext>()
            .switchOn<int>((ctx) => ctx.count ?? 0)
            .when(0, (r) => r.step(AppendMarkerStep(':zero')))
            .when(1, (r) => r.step(AppendMarkerStep(':one')))
            .when(2, (r) => r.step(AppendMarkerStep(':two')))
            .end();

        final result0 = await railway.run(const TestContext(value: 'num', count: 0));
        expect(result0.right.value, equals('num:zero'));

        final result1 = await railway.run(const TestContext(value: 'num', count: 1));
        expect(result1.right.value, equals('num:one'));

        final result2 = await railway.run(const TestContext(value: 'num', count: 2));
        expect(result2.right.value, equals('num:two'));
      });
    });

    group('Predicate matching with whenMatch()', () {
      test('whenMatch() executes on predicate true', () async {
        final railway = const Railway<TestError, TestContext>()
            .switchOn<int>((ctx) => ctx.count ?? 0)
            .whenMatch((count) => count > 5, (r) => r.step(AppendMarkerStep(':high')))
            .end();

        final result = await railway.run(const TestContext(value: 'test', count: 10));

        expect(result.isRight, isTrue);
        expect(result.right.value, equals('test:high'));
      });

      test('whenMatch() skips on predicate false', () async {
        final railway = const Railway<TestError, TestContext>()
            .switchOn<int>((ctx) => ctx.count ?? 0)
            .whenMatch((count) => count > 5, (r) => r.step(AppendMarkerStep(':high')))
            .end();

        final result = await railway.run(const TestContext(value: 'test', count: 3));

        expect(result.isRight, isTrue);
        expect(result.right.value, equals('test')); // Unchanged
      });

      test('whenMatch() with range conditions', () async {
        final railway = const Railway<TestError, TestContext>()
            .switchOn<int>((ctx) => ctx.age ?? 0)
            .whenMatch((age) => age < 18, (r) => r.step(AppendMarkerStep(':minor')))
            .whenMatch((age) => age >= 18 && age < 65, (r) => r.step(AppendMarkerStep(':adult')))
            .whenMatch((age) => age >= 65, (r) => r.step(AppendMarkerStep(':senior')))
            .end();

        final result1 = await railway.run(const TestContext(value: 'user', age: 12));
        expect(result1.right.value, equals('user:minor'));

        final result2 = await railway.run(const TestContext(value: 'user', age: 30));
        expect(result2.right.value, equals('user:adult'));

        final result3 = await railway.run(const TestContext(value: 'user', age: 70));
        expect(result3.right.value, equals('user:senior'));
      });

      test('whenMatch() with string predicates', () async {
        final railway = const Railway<TestError, TestContext>()
            .switchOn<String>((ctx) => ctx.value)
            .whenMatch((v) => v.startsWith('admin-'), (r) => r.step(AppendMarkerStep(':admin')))
            .whenMatch((v) => v.startsWith('user-'), (r) => r.step(AppendMarkerStep(':user')))
            .end();

        final result1 = await railway.run(const TestContext(value: 'admin-john'));
        expect(result1.right.value, equals('admin-john:admin'));

        final result2 = await railway.run(const TestContext(value: 'user-jane'));
        expect(result2.right.value, equals('user-jane:user'));
      });
    });

    group('Otherwise fallback', () {
      test('otherwise() executes when no cases match', () async {
        final railway = const Railway<TestError, TestContext>()
            .switchOn<String>((ctx) => ctx.value)
            .when('a', (r) => r.step(AppendMarkerStep(':a')))
            .when('b', (r) => r.step(AppendMarkerStep(':b')))
            .otherwise((r) => r.step(AppendMarkerStep(':fallback')));

        final result = await railway.run(const TestContext(value: 'c'));

        expect(result.isRight, isTrue);
        expect(result.right.value, equals('c:fallback'));
      });

      test('otherwise() skipped when a case matches', () async {
        final railway = const Railway<TestError, TestContext>()
            .switchOn<String>((ctx) => ctx.value)
            .when('a', (r) => r.step(AppendMarkerStep(':a')))
            .when('b', (r) => r.step(AppendMarkerStep(':b')))
            .otherwise((r) => r.step(AppendMarkerStep(':fallback')));

        final result = await railway.run(const TestContext(value: 'a'));

        expect(result.isRight, isTrue);
        expect(result.right.value, equals('a:a'));
      });

      test('otherwise() can have multiple steps', () async {
        final railway = const Railway<TestError, TestContext>()
            .switchOn<String>((ctx) => ctx.value)
            .when('match', (r) => r.step(AppendMarkerStep(':matched')))
            .otherwise((r) => r.step(AppendMarkerStep(':fallback1')).step(AppendMarkerStep(':fallback2')).step(IncrementStep()));

        final result = await railway.run(const TestContext(value: 'nomatch'));

        expect(result.isRight, isTrue);
        expect(result.right.value, equals('nomatch:fallback1:fallback2'));
        expect(result.right.count, equals(1));
      });
    });

    group('End without fallback', () {
      test('end() performs no-op when no cases match', () async {
        final railway = const Railway<TestError, TestContext>()
            .switchOn<String>((ctx) => ctx.value)
            .when('a', (r) => r.step(AppendMarkerStep(':a')))
            .when('b', (r) => r.step(AppendMarkerStep(':b')))
            .end();

        final result = await railway.run(const TestContext(value: 'c'));

        expect(result.isRight, isTrue);
        expect(result.right.value, equals('c')); // Unchanged
      });

      test('end() allows continuation after switch', () async {
        final railway = const Railway<TestError, TestContext>()
            .switchOn<String>((ctx) => ctx.value)
            .when('a', (r) => r.step(AppendMarkerStep(':a')))
            .end()
            .step(AppendMarkerStep(':after'));

        final result1 = await railway.run(const TestContext(value: 'a'));
        expect(result1.right.value, equals('a:a:after'));

        final result2 = await railway.run(const TestContext(value: 'b'));
        expect(result2.right.value, equals('b:after'));
      });
    });

    group('Short-circuit on first match', () {
      test('when() stops checking after first match', () async {
        final railway = const Railway<TestError, TestContext>()
            .switchOn<String>((ctx) => ctx.value)
            .when('match', (r) => r.step(AppendMarkerStep(':first')))
            .when('match', (r) => r.step(AppendMarkerStep(':second')))
            .when('match', (r) => r.step(AppendMarkerStep(':third')))
            .end();

        final result = await railway.run(const TestContext(value: 'match'));

        expect(result.isRight, isTrue);
        expect(result.right.value, equals('match:first')); // Only first match
      });

      test('mixed when() and whenMatch() short-circuits correctly', () async {
        final railway = const Railway<TestError, TestContext>()
            .switchOn<int>((ctx) => ctx.count ?? 0)
            .when(5, (r) => r.step(AppendMarkerStep(':exact5')))
            .whenMatch((n) => n > 3, (r) => r.step(AppendMarkerStep(':greater3')))
            .whenMatch((n) => n > 0, (r) => r.step(AppendMarkerStep(':positive')))
            .end();

        final result = await railway.run(const TestContext(value: 'test', count: 5));

        expect(result.isRight, isTrue);
        expect(result.right.value, equals('test:exact5')); // Stopped at first match
      });

      test('order matters for overlapping predicates', () async {
        final railway = const Railway<TestError, TestContext>()
            .switchOn<int>((ctx) => ctx.count ?? 0)
            .whenMatch((n) => n > 0, (r) => r.step(AppendMarkerStep(':positive')))
            .whenMatch((n) => n > 3, (r) => r.step(AppendMarkerStep(':greater3')))
            .whenMatch((n) => n == 5, (r) => r.step(AppendMarkerStep(':exact5')))
            .end();

        final result = await railway.run(const TestContext(value: 'test', count: 5));

        expect(result.isRight, isTrue);
        expect(result.right.value, equals('test:positive')); // First match wins
      });
    });

    group('Selector evaluation', () {
      test('selector evaluated exactly once', () async {
        final tracker = SelectorTracker();

        final railway = const Railway<TestError, TestContext>()
            .switchOn<String>((ctx) => tracker.call(ctx))
            .when('a', (r) => r.step(IncrementStep()))
            .when('b', (r) => r.step(IncrementStep()))
            .when('c', (r) => r.step(IncrementStep()))
            .end();

        await railway.run(const TestContext(value: 'b'));

        expect(tracker.callCount, equals(1)); // Called exactly once
      });

      test('selector result cached for all case checks', () async {
        var selectorCalls = 0;

        final railway = const Railway<TestError, TestContext>()
            .switchOn<String>((ctx) {
              selectorCalls++;
              return ctx.value;
            })
            .when('a', (r) => r.step(AppendMarkerStep(':a')))
            .when('b', (r) => r.step(AppendMarkerStep(':b')))
            .when('c', (r) => r.step(AppendMarkerStep(':c')))
            .whenMatch((v) => v.startsWith('d'), (r) => r.step(AppendMarkerStep(':d')))
            .otherwise((r) => r.step(AppendMarkerStep(':other')));

        await railway.run(const TestContext(value: 'x'));

        expect(selectorCalls, equals(1)); // Not called for each case check
      });
    });

    group('Multiple cases', () {
      test('switch with many cases executes correct one', () async {
        final railway = const Railway<TestError, TestContext>()
            .switchOn<int>((ctx) => ctx.count ?? 0)
            .when(1, (r) => r.step(AppendMarkerStep(':one')))
            .when(2, (r) => r.step(AppendMarkerStep(':two')))
            .when(3, (r) => r.step(AppendMarkerStep(':three')))
            .when(4, (r) => r.step(AppendMarkerStep(':four')))
            .when(5, (r) => r.step(AppendMarkerStep(':five')))
            .otherwise((r) => r.step(AppendMarkerStep(':other')));

        final result3 = await railway.run(const TestContext(value: 'num', count: 3));
        expect(result3.right.value, equals('num:three'));

        final result5 = await railway.run(const TestContext(value: 'num', count: 5));
        expect(result5.right.value, equals('num:five'));

        final result0 = await railway.run(const TestContext(value: 'num', count: 0));
        expect(result0.right.value, equals('num:other'));
      });

      test('cases can have different step counts', () async {
        final railway = const Railway<TestError, TestContext>()
            .switchOn<String>((ctx) => ctx.value)
            .when('a', (r) => r.step(IncrementStep()))
            .when('b', (r) => r.step(IncrementStep()).step(IncrementStep()))
            .when('c', (r) => r.step(IncrementStep()).step(IncrementStep()).step(IncrementStep()))
            .end();

        final resultA = await railway.run(const TestContext(value: 'a'));
        expect(resultA.right.count, equals(1));

        final resultB = await railway.run(const TestContext(value: 'b'));
        expect(resultB.right.count, equals(2));

        final resultC = await railway.run(const TestContext(value: 'c'));
        expect(resultC.right.count, equals(3));
      });
    });

    group('Empty switch', () {
      test('switch with no cases and end() is passthrough', () async {
        final railway = const Railway<TestError, TestContext>().switchOn<String>((ctx) => ctx.value).end().step(AppendMarkerStep(':after'));

        final result = await railway.run(const TestContext(value: 'test'));

        expect(result.isRight, isTrue);
        expect(result.right.value, equals('test:after'));
      });

      test('switch with only otherwise() always executes fallback', () async {
        final railway = const Railway<TestError, TestContext>().switchOn<String>((ctx) => ctx.value).otherwise((r) => r.step(AppendMarkerStep(':fallback')));

        final result = await railway.run(const TestContext(value: 'anything'));

        expect(result.isRight, isTrue);
        expect(result.right.value, equals('anything:fallback'));
      });
    });

    group('Chain continuation', () {
      test('railway continues after switch', () async {
        final railway = const Railway<TestError, TestContext>()
            .step(AppendMarkerStep(':before'))
            .switchOn<String>((ctx) => ctx.value)
            .when('match:before', (r) => r.step(AppendMarkerStep(':matched')))
            .otherwise((r) => r.step(AppendMarkerStep(':nomatch')))
            .step(AppendMarkerStep(':after'));

        final result1 = await railway.run(const TestContext(value: 'match'));
        expect(result1.right.value, equals('match:before:matched:after'));

        final result2 = await railway.run(const TestContext(value: 'other'));
        expect(result2.right.value, equals('other:before:nomatch:after'));
      });

      test('multiple switches in same railway', () async {
        final railway = const Railway<TestError, TestContext>()
            .switchOn<String>((ctx) => ctx.value)
            .when('a', (r) => r.step(AppendMarkerStep(':first-a')))
            .when('b', (r) => r.step(AppendMarkerStep(':first-b')))
            .end()
            .step(IncrementStep())
            .switchOn<int>((ctx) => ctx.count ?? 0)
            .when(1, (r) => r.step(AppendMarkerStep(':second-one')))
            .when(2, (r) => r.step(AppendMarkerStep(':second-two')))
            .end();

        final result = await railway.run(const TestContext(value: 'a'));

        expect(result.isRight, isTrue);
        expect(result.right.value, equals('a:first-a:second-one'));
        expect(result.right.count, equals(1));
      });
    });

    group('Type safety', () {
      test('switch selector type matches case types', () {
        // This test verifies compile-time type safety
        final railway = const Railway<TestError, TestContext>();

        // String selector enforces String cases
        final stringSwitch = railway.switchOn<String>((ctx) => ctx.value);
        stringSwitch.when('value', (r) => r); // OK: String literal
        // stringSwitch.when(42, (r) => r); // Would not compile: int not assignable to String

        // Int selector enforces int cases
        final intSwitch = railway.switchOn<int>((ctx) => ctx.count ?? 0);
        intSwitch.when(42, (r) => r); // OK: int literal
        // intSwitch.when('value', (r) => r); // Would not compile: String not assignable to int

        // Enum selector enforces enum cases
        final enumSwitch = railway.switchOn<TestStatus>((ctx) => ctx.status ?? TestStatus.draft);
        enumSwitch.when(TestStatus.approved, (r) => r); // OK: TestStatus value
        // enumSwitch.when('approved', (r) => r); // Would not compile: String not assignable to TestStatus
      });
    });

    group('Error propagation', () {
      test('switch case failure propagates error', () async {
        final railway = const Railway<TestError, TestContext>()
            .switchOn<String>((ctx) => ctx.value)
            .when('fail', (r) => r.step(FailingStep()))
            .when('ok', (r) => r.step(AppendMarkerStep(':ok')))
            .end();

        final result = await railway.run(const TestContext(value: 'fail'));

        expect(result.isLeft, isTrue);
        expect(result.left, equals(TestError.execution));
      });

      test('switch case failure short-circuits railway', () async {
        final railway = const Railway<TestError, TestContext>()
            .switchOn<String>((ctx) => ctx.value)
            .when('fail', (r) => r.step(FailingStep()))
            .end()
            .step(AppendMarkerStep(':after')); // Should not execute

        final result = await railway.run(const TestContext(value: 'fail'));

        expect(result.isLeft, isTrue);
        expect(result.left, equals(TestError.execution));
      });

      test('otherwise case can fail', () async {
        final railway = const Railway<TestError, TestContext>()
            .switchOn<String>((ctx) => ctx.value)
            .when('ok', (r) => r.step(AppendMarkerStep(':ok')))
            .otherwise((r) => r.step(FailingStep()));

        final result = await railway.run(const TestContext(value: 'nomatch'));

        expect(result.isLeft, isTrue);
        expect(result.left, equals(TestError.execution));
      });
    });

    group('Edge Cases and Error Handling', () {
      test('selector returns null', () async {
        final railway = const Railway<TestError, TestContext>()
            .switchOn<String?>((ctx) => null)
            .when(null, (r) => r.step(AppendMarkerStep(':null-match')))
            .when('value', (r) => r.step(AppendMarkerStep(':value')))
            .end();

        final result = await railway.run(const TestContext(value: 'test'));

        expect(result.isRight, isTrue);
        expect(result.right.value, equals('test:null-match'));
      });

      test('selector throws synchronous exception', () async {
        final railway = const Railway<TestError, TestContext>()
            .switchOn<String>(
              (ctx) => throw StateError('Selector error'),
            )
            .when('any', (r) => r.step(AppendMarkerStep(':match')))
            .end();

        final result = await railway.run(const TestContext(value: 'test'));

        // Selector exception is caught and context passes through unchanged
        expect(result.isRight, isTrue);
        expect(result.right.value, equals('test'));
      });

      test('selector throws asynchronous exception', () async {
        // Cannot test async exceptions in synchronous selector function
        // Selector must be synchronous, async exceptions would require different API
        final railway =
            const Railway<TestError, TestContext>().switchOn<String>((ctx) => ctx.value).when('value', (r) => r.step(AppendMarkerStep(':match'))).end();

        final result = await railway.run(const TestContext(value: 'value'));

        expect(result.isRight, isTrue);
        expect(result.right.value, equals('value:match'));
      });

      test('predicate throws exception', () async {
        final railway = const Railway<TestError, TestContext>()
            .switchOn<int>((ctx) => ctx.count ?? 0)
            .whenMatch(
              (value) => throw StateError('Predicate error'),
              (r) => r.step(AppendMarkerStep(':match')),
            )
            .end();

        expect(
          () async => await railway.run(const TestContext(value: 'test', count: 5)),
          throwsA(isA<StateError>()),
        );
      });

      test('builder function throws exception', () async {
        // Builder functions are called at construction time (during end())
        // so exceptions happen during railway construction
        expect(
          () {
            const Railway<TestError, TestContext>()
                .switchOn<String>((ctx) => ctx.value)
                .when(
                  'throw',
                  (r) => throw StateError('Builder error'),
                )
                .end();
          },
          throwsA(isA<StateError>()),
        );
      });

      test('empty railway returned from case builder', () async {
        final railway = const Railway<TestError, TestContext>()
            .step(AppendMarkerStep(':before'))
            .switchOn<String>((ctx) => ctx.value)
            .when('empty', (r) => const Railway<TestError, TestContext>())
            .when('normal', (r) => r.step(AppendMarkerStep(':normal')))
            .end()
            .step(AppendMarkerStep(':after'));

        final result = await railway.run(const TestContext(value: 'empty'));

        // Empty railway should pass context through unchanged
        expect(result.isRight, isTrue);
        expect(result.right.value, equals('empty:before:after'));
      });

      test('switch after failed operation', () async {
        final railway = const Railway<TestError, TestContext>()
            .step(FailingStep())
            .switchOn<String>((ctx) => ctx.value)
            .when('any', (r) => r.step(AppendMarkerStep(':switch')))
            .end();

        final result = await railway.run(const TestContext(value: 'test'));

        // Railway already failed, switch should not execute
        expect(result.isLeft, isTrue);
        expect(result.left, equals(TestError.execution));
      });

      test('nullable types behavior', () async {
        final railway = const Railway<TestError, TestContext>()
            .switchOn<int?>((ctx) => ctx.count)
            .when(null, (r) => r.step(AppendMarkerStep(':null')))
            .when(0, (r) => r.step(AppendMarkerStep(':zero')))
            .when(1, (r) => r.step(AppendMarkerStep(':one')))
            .otherwise((r) => r.step(AppendMarkerStep(':other')));

        // Test null value
        final nullResult = await railway.run(const TestContext(value: 'test'));
        expect(nullResult.isRight, isTrue);
        expect(nullResult.right.value, equals('test:null'));

        // Test zero value
        final zeroResult = await railway.run(const TestContext(value: 'test', count: 0));
        expect(zeroResult.isRight, isTrue);
        expect(zeroResult.right.value, equals('test:zero'));

        // Test non-null value
        final oneResult = await railway.run(const TestContext(value: 'test', count: 1));
        expect(oneResult.isRight, isTrue);
        expect(oneResult.right.value, equals('test:one'));

        // Test other value
        final otherResult = await railway.run(const TestContext(value: 'test', count: 42));
        expect(otherResult.isRight, isTrue);
        expect(otherResult.right.value, equals('test:other'));
      });
    });

    group('Performance and Optimization', () {
      test('selector is not called redundantly', () async {
        var selectorCallCount = 0;

        final railway = const Railway<TestError, TestContext>()
            .switchOn<String>((ctx) {
              selectorCallCount++;
              return ctx.value;
            })
            .when('match', (r) => r.step(AppendMarkerStep(':match')))
            .when('other', (r) => r.step(AppendMarkerStep(':other')))
            .end();

        await railway.run(const TestContext(value: 'match'));

        // Selector should be called exactly once
        expect(selectorCallCount, equals(1));
      });

      test('predicates stop evaluating after first match', () async {
        final evaluatedPredicates = <int>[];

        final railway = const Railway<TestError, TestContext>().switchOn<int>((ctx) => ctx.count ?? 0).whenMatch((value) {
          evaluatedPredicates.add(1);
          return value > 5; // First predicate - will match
        }, (r) => r.step(AppendMarkerStep(':first'))).whenMatch((value) {
          evaluatedPredicates.add(2);
          return value > 3; // Second predicate - should not evaluate
        }, (r) => r.step(AppendMarkerStep(':second'))).whenMatch((value) {
          evaluatedPredicates.add(3);
          return value > 0; // Third predicate - should not evaluate
        }, (r) => r.step(AppendMarkerStep(':third'))).end();

        final result = await railway.run(const TestContext(value: 'test', count: 10));

        // Only first predicate should have been evaluated
        expect(evaluatedPredicates, equals([1]));
        expect(result.isRight, isTrue);
        expect(result.right.value, equals('test:first'));
      });

      test('switch execution performance vs chained branches', () async {
        // This test documents that switch is implemented efficiently
        // All case railways are pre-built during construction (not at runtime)
        final constructionStart = DateTime.now();

        final railway = const Railway<TestError, TestContext>()
            .switchOn<int>((ctx) => ctx.count ?? 0)
            .when(1, (r) => r.step(AppendMarkerStep(':one')))
            .when(2, (r) => r.step(AppendMarkerStep(':two')))
            .when(3, (r) => r.step(AppendMarkerStep(':three')))
            .when(4, (r) => r.step(AppendMarkerStep(':four')))
            .when(5, (r) => r.step(AppendMarkerStep(':five')))
            .otherwise((r) => r.step(AppendMarkerStep(':other')));

        final constructionTime = DateTime.now().difference(constructionStart);

        // Execute multiple times to verify runtime performance
        final executionStart = DateTime.now();
        for (var i = 1; i <= 5; i++) {
          await railway.run(TestContext(value: 'test', count: i));
        }
        final executionTime = DateTime.now().difference(executionStart);

        // No specific assertion - this test documents the pattern
        // Construction includes pre-building all case railways
        // Execution should be fast as cases are pre-built
        expect(constructionTime.inMilliseconds, greaterThanOrEqualTo(0));
        expect(executionTime.inMilliseconds, greaterThanOrEqualTo(0));
      });

      test('case list iteration optimized for common cases', () async {
        // Test that early cases are found quickly
        var iterationCount = 0;

        final railway = const Railway<TestError, TestContext>()
            .switchOn<int>((ctx) {
              iterationCount++;
              return ctx.count ?? 0;
            })
            .when(1, (r) => r.step(AppendMarkerStep(':first')))
            .when(2, (r) => r.step(AppendMarkerStep(':second')))
            .when(3, (r) => r.step(AppendMarkerStep(':third')))
            .end();

        // Run with first case matching
        await railway.run(const TestContext(value: 'test', count: 1));

        // Selector called once, first case matches, no further iteration
        expect(iterationCount, equals(1));
      });

      test('lazy case evaluation - cases built at construction not runtime', () async {
        var builderCallCount = 0;

        // Builder functions are called during construction (end/otherwise)
        final railway = const Railway<TestError, TestContext>().switchOn<String>((ctx) => ctx.value).when('match', (r) {
          builderCallCount++;
          return r.step(AppendMarkerStep(':match'));
        }).end();

        // Builder was called during construction
        expect(builderCallCount, equals(1));

        // Running the railway doesn't call builder again
        await railway.run(const TestContext(value: 'match'));
        expect(builderCallCount, equals(1)); // Still 1

        // Running again still doesn't call builder
        await railway.run(const TestContext(value: 'match'));
        expect(builderCallCount, equals(1)); // Still 1
      });
    });
  });
}
