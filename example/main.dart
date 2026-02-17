// ignore_for_file: avoid_print

import 'package:either_dart/either.dart';
import 'package:gradis/gradis.dart';

// Example: Create User Workflow
// This demonstrates a complete workflow with guards and steps

void main() async {
  print('=== Gradis Railway Example ===\n');

  // Successful workflow
  print('1. Successful user creation:');
  final result1 = await createUser('john@example.com', 'SecurePass123!');
  result1.fold(
    (error) => print('   Error: $error'),
    (ctx) => print('   Success! User ID: ${ctx.userId}, Email verified: ${ctx.emailVerified}'),
  );

  // Invalid email
  print('\n2. Invalid email:');
  final result2 = await createUser('invalid-email', 'SecurePass123!');
  result2.fold(
    (error) => print('   Error: $error'),
    (ctx) => print('   Success!'),
  );

  // Weak password
  print('\n3. Weak password:');
  final result3 = await createUser('jane@example.com', '123');
  result3.fold(
    (error) => print('   Error: $error'),
    (ctx) => print('   Success!'),
  );
}

// Context definition
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

  CreateUserContext copyWith({String? userId, bool? emailVerified}) {
    return CreateUserContext(
      email: email,
      password: password,
      userId: userId ?? this.userId,
      emailVerified: emailVerified ?? this.emailVerified,
    );
  }
}

// Unified error type for the workflow
enum CreateUserError {
  invalidEmail,
  weakPassword,
  userAlreadyExists,
  saveFailed,
}

// Guards - Validation without mutation
class EmailValidationGuard implements RailwayGuard<CreateUserContext, CreateUserError> {
  @override
  Future<Either<CreateUserError, void>> check(CreateUserContext context) async {
    if (!context.email.contains('@') || !context.email.contains('.')) {
      return const Left(CreateUserError.invalidEmail);
    }
    return const Right(null);
  }
}

class PasswordStrengthGuard implements RailwayGuard<CreateUserContext, CreateUserError> {
  @override
  Future<Either<CreateUserError, void>> check(CreateUserContext context) async {
    if (context.password.length < 8) {
      return const Left(CreateUserError.weakPassword);
    }
    return const Right(null);
  }
}

// Steps - State mutation with context updates
class CreateUserStep implements RailwayStep<CreateUserContext, CreateUserError> {
  @override
  Future<Either<CreateUserError, CreateUserContext>> run(CreateUserContext context) async {
    // Simulate user creation
    await Future<void>.delayed(const Duration(milliseconds: 100));

    // Generate user ID
    final userId = 'user_${DateTime.now().millisecondsSinceEpoch}';

    return Right(context.copyWith(userId: userId));
  }
}

class SendVerificationEmailStep implements RailwayStep<CreateUserContext, CreateUserError> {
  @override
  Future<Either<CreateUserError, CreateUserContext>> run(CreateUserContext context) async {
    // Simulate sending email
    await Future.delayed(const Duration(milliseconds: 100));

    return Right(context.copyWith(emailVerified: true));
  }
}

// Build and execute the railway
Future<Either<CreateUserError, CreateUserContext>> createUser(
  String email,
  String password,
) async {
  final railway = const Railway<CreateUserContext, CreateUserError>()
      .guard(EmailValidationGuard())
      .guard(PasswordStrengthGuard())
      .step(CreateUserStep())
      .step(SendVerificationEmailStep());

  final initialContext = CreateUserContext(email: email, password: password);

  return await railway.run(initialContext);
}
