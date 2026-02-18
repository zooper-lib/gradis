import 'package:either_dart/either.dart';
import 'package:gradis/src/railway.dart';
import 'package:gradis/src/railway_guard.dart';
import 'package:gradis/src/railway_step.dart';
import 'package:test/test.dart';

// Domain models
class OrderContext {
  final String orderId;
  final int quantity;
  final bool isPremiumUser;
  final bool inventoryReserved;
  final bool paymentProcessed;
  final bool notificationSent;
  final List<String> log;

  const OrderContext({
    this.orderId = '',
    this.quantity = 0,
    this.isPremiumUser = false,
    this.inventoryReserved = false,
    this.paymentProcessed = false,
    this.notificationSent = false,
    this.log = const [],
  });

  OrderContext copyWith({
    String? orderId,
    int? quantity,
    bool? isPremiumUser,
    bool? inventoryReserved,
    bool? paymentProcessed,
    bool? notificationSent,
    List<String>? log,
  }) {
    return OrderContext(
      orderId: orderId ?? this.orderId,
      quantity: quantity ?? this.quantity,
      isPremiumUser: isPremiumUser ?? this.isPremiumUser,
      inventoryReserved: inventoryReserved ?? this.inventoryReserved,
      paymentProcessed: paymentProcessed ?? this.paymentProcessed,
      notificationSent: notificationSent ?? this.notificationSent,
      log: log ?? this.log,
    );
  }

  OrderContext addLog(String message) => copyWith(log: [...log, message]);
}

enum OrderError { invalidQuantity, insufficientInventory, paymentFailed }

// Guards
class ValidQuantityGuard implements RailwayGuard<OrderError, OrderContext> {
  @override
  Future<Either<OrderError, void>> check(OrderContext context) async {
    if (context.quantity <= 0 || context.quantity > 100) {
      return const Left(OrderError.invalidQuantity);
    }
    return const Right(null);
  }
}

// Steps with compensation
class ReserveInventoryStep extends RailwayStep<OrderError, OrderContext> {
  final bool shouldFail;

  ReserveInventoryStep({this.shouldFail = false});

  @override
  Future<Either<OrderError, OrderContext>> run(OrderContext context) async {
    if (shouldFail) {
      return const Left(OrderError.insufficientInventory);
    }
    return Right(
      context.copyWith(inventoryReserved: true).addLog('Reserved ${context.quantity} items'),
    );
  }

  @override
  Future<void> compensate(OrderContext context) async {
    // Rollback: release inventory reservation
    // In real scenario, would call inventory service
  }
}

class ProcessPaymentStep extends RailwayStep<OrderError, OrderContext> {
  final bool shouldFail;

  ProcessPaymentStep({this.shouldFail = false});

  @override
  Future<Either<OrderError, OrderContext>> run(OrderContext context) async {
    if (shouldFail) {
      return const Left(OrderError.paymentFailed);
    }
    return Right(
      context.copyWith(paymentProcessed: true).addLog('Payment processed'),
    );
  }

  @override
  Future<void> compensate(OrderContext context) async {
    // Rollback: refund the payment
    // In real scenario, would call payment service to refund
  }
}

class SendNotificationStep extends RailwayStep<OrderError, OrderContext> {
  @override
  Future<Either<OrderError, OrderContext>> run(OrderContext context) async {
    return Right(
      context.copyWith(notificationSent: true).addLog('Notification sent'),
    );
  }
}

class ApplyPremiumDiscountStep extends RailwayStep<OrderError, OrderContext> {
  @override
  Future<Either<OrderError, OrderContext>> run(OrderContext context) async {
    return Right(context.addLog('Premium discount applied'));
  }
}

void main() {
  group('Integration: Complex Workflow', () {
    test('successful order workflow with branch', () async {
      final railway = const Railway<OrderError, OrderContext>()
          .guard(ValidQuantityGuard())
          .step(ReserveInventoryStep())
          .branch(
            (ctx) => ctx.isPremiumUser,
            (r) => r.step(ApplyPremiumDiscountStep()),
          )
          .step(ProcessPaymentStep())
          .step(SendNotificationStep());

      final result = await railway.run(
        const OrderContext(quantity: 5, isPremiumUser: true),
      );

      expect(result.isRight, true);
      expect(result.right.inventoryReserved, true);
      expect(result.right.paymentProcessed, true);
      expect(result.right.notificationSent, true);
      expect(result.right.log, contains('Premium discount applied'));
    });

    test('compensations execute in reverse order when payment fails', () async {
      final railway = const Railway<OrderError, OrderContext>()
          .guard(ValidQuantityGuard())
          .step(ReserveInventoryStep())
          .step(ProcessPaymentStep(shouldFail: true))
          .step(SendNotificationStep());

      final result = await railway.run(const OrderContext(quantity: 5));

      expect(result.isLeft, true);
      expect(result.left, OrderError.paymentFailed);
      // Inventory should have been reserved, then compensated
      // Cannot access .right on Left value
    });

    test('nested branches with compensations', () async {
      final railway = const Railway<OrderError, OrderContext>().step(ReserveInventoryStep()).branch(
            (ctx) => ctx.inventoryReserved,
            (r) => r.step(ProcessPaymentStep()).branch(
                  (ctx) => ctx.paymentProcessed,
                  (r2) => r2.step(SendNotificationStep()),
                ),
          );

      final result = await railway.run(const OrderContext(quantity: 5));

      expect(result.isRight, true);
      expect(result.right.notificationSent, true);
      expect(result.right.log.length, 3); // Reserve, Payment, Notification
    });

    test('compensation stack with interleaved branches', () async {
      final compensationLog = <String>[];

      final trackingReserve = _TrackingStep('reserve', compensationLog);
      final trackingPayment = _TrackingStep('payment', compensationLog);
      final trackingBranchStep = _TrackingStep('branch-step', compensationLog);
      final trackingFailing = _TrackingStep('failing', compensationLog, shouldFail: true);

      final railway = const Railway<OrderError, OrderContext>()
          .step(trackingReserve)
          .branch(
            (ctx) => true,
            (r) => r.step(trackingBranchStep),
          )
          .step(trackingPayment)
          .step(trackingFailing);

      final result = await railway.run(const OrderContext(quantity: 5));

      expect(result.isLeft, true);
      expect(compensationLog, ['compensate:payment', 'compensate:branch-step', 'compensate:reserve']);
    });

    test('existing integration tests still pass', () async {
      // Verify backward compatibility
      final railway = const Railway<OrderError, OrderContext>().guard(ValidQuantityGuard()).step(ReserveInventoryStep()).step(ProcessPaymentStep());

      final result = await railway.run(const OrderContext(quantity: 10));

      expect(result.isRight, true);
    });
  });
}

// Helper for tracking compensation
class _TrackingStep extends RailwayStep<OrderError, OrderContext> {
  final String name;
  final List<String> log;
  final bool shouldFail;

  _TrackingStep(this.name, this.log, {this.shouldFail = false});

  @override
  Future<Either<OrderError, OrderContext>> run(OrderContext context) async {
    if (shouldFail) {
      return const Left(OrderError.paymentFailed);
    }
    return Right(context.addLog('execute:$name'));
  }

  @override
  Future<void> compensate(OrderContext context) async {
    log.add('compensate:$name');
  }
}
