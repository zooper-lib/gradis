import 'package:either_dart/either.dart';
import 'package:gradis/gradis.dart';
import 'package:test/test.dart';

// Domain context for user creation workflow
final class CreateUserContext {
  final String email;
  final String password;
  final String? userId;
  final bool? emailVerified;

  const CreateUserContext({
    required this.email,
    required this.password,
    this.userId,
    this.emailVerified,
  });

  CreateUserContext copyWith({
    String? userId,
    bool? emailVerified,
  }) {
    return CreateUserContext(
      email: email,
      password: password,
      userId: userId ?? this.userId,
      emailVerified: emailVerified ?? this.emailVerified,
    );
  }
}

// Unified workflow error type
enum CreateUserError {
  invalidEmail,
  weakPassword,
  userExists,
  saveFailed,
  verificationFailed,
}

// Domain-specific error types (internal)
enum EmailValidationError { invalid, malformed }

enum PasswordError { tooShort, tooWeak }

enum RepositoryError { alreadyExists, connectionFailed }

// Guards with error mapping
class EmailFormatGuard implements RailwayGuard<CreateUserContext, CreateUserError> {
  @override
  Future<Either<CreateUserError, void>> check(CreateUserContext context) async {
    // Simulate internal validation with different error type
    final internalResult = _validateEmail(context.email);

    // Map internal error to workflow error
    return internalResult.fold(
      (error) => const Left(CreateUserError.invalidEmail),
      (_) => const Right(null),
    );
  }

  Either<EmailValidationError, void> _validateEmail(String email) {
    if (!email.contains('@')) {
      return const Left(EmailValidationError.invalid);
    }
    return const Right(null);
  }
}

class PasswordStrengthGuard implements RailwayGuard<CreateUserContext, CreateUserError> {
  @override
  Future<Either<CreateUserError, void>> check(CreateUserContext context) async {
    final internalResult = _validatePassword(context.password);

    // Map internal error to workflow error
    return internalResult.fold(
      (error) => const Left(CreateUserError.weakPassword),
      (_) => const Right(null),
    );
  }

  Either<PasswordError, void> _validatePassword(String password) {
    if (password.length < 8) {
      return const Left(PasswordError.tooShort);
    }
    return const Right(null);
  }
}

// Steps with error mapping and side effects
class CreateUserStep extends RailwayStep<CreateUserContext, CreateUserError> {
  final MockUserRepository repository;

  CreateUserStep(this.repository);

  @override
  Future<Either<CreateUserError, CreateUserContext>> run(
    CreateUserContext context,
  ) async {
    // Call repository (internal error type)
    final internalResult = await repository.create(context.email, context.password);

    // Map repository error to workflow error
    return internalResult.fold(
      (error) {
        if (error == RepositoryError.alreadyExists) {
          return const Left(CreateUserError.userExists);
        }
        return const Left(CreateUserError.saveFailed);
      },
      (userId) => Right(context.copyWith(userId: userId)),
    );
  }
}

class VerifyEmailStep extends RailwayStep<CreateUserContext, CreateUserError> {
  final MockEmailService emailService;

  VerifyEmailStep(this.emailService);

  @override
  Future<Either<CreateUserError, CreateUserContext>> run(
    CreateUserContext context,
  ) async {
    final sent = await emailService.sendVerification(context.email);

    if (!sent) {
      return const Left(CreateUserError.verificationFailed);
    }

    return Right(context.copyWith(emailVerified: true));
  }
}

// Mock repository with internal error type
class MockUserRepository {
  final bool userExists;
  final bool shouldFail;
  final List<String> createdUsers = [];

  MockUserRepository({this.userExists = false, this.shouldFail = false});

  Future<Either<RepositoryError, String>> create(
    String email,
    String password,
  ) async {
    if (userExists) {
      return const Left(RepositoryError.alreadyExists);
    }
    if (shouldFail) {
      return const Left(RepositoryError.connectionFailed);
    }

    createdUsers.add(email);
    return Right('user-${createdUsers.length}');
  }
}

// Mock email service
class MockEmailService {
  final bool shouldFail;
  final List<String> sentTo = [];

  MockEmailService({this.shouldFail = false});

  Future<bool> sendVerification(String email) async {
    if (shouldFail) return false;
    sentTo.add(email);
    return true;
  }
}

// Mock transaction runner
class MockTransactionRunner {
  bool transactionStarted = false;
  bool transactionCommitted = false;

  Future<Either<E, R>> runAsync<E, R>(
    Future<Either<E, R>> Function() operation,
  ) async {
    transactionStarted = true;
    final result = await operation();
    if (result.isRight) {
      transactionCommitted = true;
    }
    return result;
  }
}

void main() {
  group('Integration Tests', () {
    test('complete workflow with multiple guards and steps', () async {
      final repository = MockUserRepository();
      final emailService = MockEmailService();

      final railway = const Railway<CreateUserContext, CreateUserError>()
          .guard(EmailFormatGuard())
          .guard(PasswordStrengthGuard())
          .step(CreateUserStep(repository))
          .step(VerifyEmailStep(emailService));

      final context = const CreateUserContext(
        email: 'user@example.com',
        password: 'securePassword123',
      );

      final result = await railway.run(context);

      expect(result.isRight, isTrue);
      expect(result.right.userId, equals('user-1'));
      expect(result.right.emailVerified, isTrue);
      expect(repository.createdUsers, contains('user@example.com'));
      expect(emailService.sentTo, contains('user@example.com'));
    });

    test('error mapping from guards to railway error type', () async {
      final repository = MockUserRepository();
      final emailService = MockEmailService();

      final railway = const Railway<CreateUserContext, CreateUserError>()
          .guard(EmailFormatGuard())
          .guard(PasswordStrengthGuard())
          .step(CreateUserStep(repository))
          .step(VerifyEmailStep(emailService));

      // Invalid email
      final result1 = await railway.run(
        const CreateUserContext(email: 'invalid', password: 'securePass123'),
      );
      expect(result1.left, equals(CreateUserError.invalidEmail));

      // Weak password
      final result2 = await railway.run(
        const CreateUserContext(email: 'user@example.com', password: 'weak'),
      );
      expect(result2.left, equals(CreateUserError.weakPassword));
    });

    test('error mapping from steps to railway error type', () async {
      final repository = MockUserRepository(userExists: true);
      final emailService = MockEmailService();

      final railway = const Railway<CreateUserContext, CreateUserError>()
          .guard(EmailFormatGuard())
          .guard(PasswordStrengthGuard())
          .step(CreateUserStep(repository))
          .step(VerifyEmailStep(emailService));

      final result = await railway.run(
        const CreateUserContext(
          email: 'existing@example.com',
          password: 'securePass123',
        ),
      );

      expect(result.isLeft, isTrue);
      expect(result.left, equals(CreateUserError.userExists));
    });

    test('context accumulation in realistic workflow scenario', () async {
      final repository = MockUserRepository();
      final emailService = MockEmailService();

      final railway = const Railway<CreateUserContext, CreateUserError>()
          .guard(EmailFormatGuard())
          .guard(PasswordStrengthGuard())
          .step(CreateUserStep(repository))
          .step(VerifyEmailStep(emailService));

      final initialContext = const CreateUserContext(
        email: 'test@example.com',
        password: 'securePass123',
      );

      final result = await railway.run(initialContext);

      expect(result.isRight, isTrue);

      final finalContext = result.right;
      // Initial data preserved
      expect(finalContext.email, equals('test@example.com'));
      expect(finalContext.password, equals('securePass123'));

      // Accumulated data from steps
      expect(finalContext.userId, isNotNull);
      expect(finalContext.emailVerified, isTrue);
    });

    test('railway execution within transaction boundary (mock)', () async {
      final repository = MockUserRepository();
      final emailService = MockEmailService();
      final transactionRunner = MockTransactionRunner();

      final railway = const Railway<CreateUserContext, CreateUserError>()
          .guard(EmailFormatGuard())
          .guard(PasswordStrengthGuard())
          .step(CreateUserStep(repository))
          .step(VerifyEmailStep(emailService));

      final context = const CreateUserContext(
        email: 'user@example.com',
        password: 'securePass123',
      );

      // Run railway within transaction
      final result = await transactionRunner.runAsync(() => railway.run(context));

      expect(result.isRight, isTrue);
      expect(transactionRunner.transactionStarted, isTrue);
      expect(transactionRunner.transactionCommitted, isTrue);
    });
  });
}
