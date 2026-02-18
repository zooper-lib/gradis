// ignore_for_file: avoid_print

import 'package:either_dart/either.dart';
import 'package:gradis/gradis.dart';

// ============================================================================
// Type Parameter Order Convention: <E, C>
// ============================================================================
// Railway uses <E, C> where:
//   E = Error type (corresponds to Either's Left channel)
//   C = Context type (corresponds to Either's Right channel)
//
// This matches the Either<L, R> convention from either_dart, making the API
// more intuitive when working with Railway<E, C> → Either<E, C> conversions.
// ============================================================================

// Example: Create User Workflow
// This demonstrates Railway pattern with guards, steps, and switch routing

void main() async {
  print('=== Gradis Railway Examples ===\n');
  print('Type parameter order: Railway<E, C> where E=Error, C=Context\n');

  // ===== Example 1: Basic Railway =====
  print('--- Example 1: Basic Railway with Guards and Steps ---');

  print('\n1.1 Successful user creation:');
  final result1 = await createUser('john@example.com', 'SecurePass123!');
  result1.fold(
    (error) => print('   Error: $error'),
    (ctx) => print('   ✓ Success! User ID: ${ctx.userId}, Email verified: ${ctx.emailVerified}'),
  );

  print('\n1.2 Invalid email:');
  final result2 = await createUser('invalid-email', 'SecurePass123!');
  result2.fold(
    (error) => print('   ✗ Error: $error'),
    (ctx) => print('   Success!'),
  );

  print('\n1.3 Weak password:');
  final result3 = await createUser('jane@example.com', '123');
  result3.fold(
    (error) => print('   ✗ Error: $error'),
    (ctx) => print('   Success!'),
  );

  // ===== Example 2: Switch Pattern - Value Matching =====
  print('\n\n--- Example 2: Switch Pattern - User Type Routing ---');

  print('\n2.1 Admin user:');
  final result4 = await createUserWithTypeRouting('admin@example.com', 'AdminPass123!', UserType.admin);
  result4.fold(
    (error) => print('   ✗ Error: $error'),
    (ctx) => print('   ✓ Success! Admin user created: ${ctx.userId}'),
  );

  print('\n2.2 Regular user:');
  final result5 = await createUserWithTypeRouting('user@example.com', 'UserPass123!', UserType.user);
  result5.fold(
    (error) => print('   ✗ Error: $error'),
    (ctx) => print('   ✓ Success! Regular user created: ${ctx.userId}'),
  );

  print('\n2.3 Guest user:');
  final result6 = await createUserWithTypeRouting('guest@example.com', 'GuestPass123!', UserType.guest);
  result6.fold(
    (error) => print('   ✗ Error: $error'),
    (ctx) => print('   ✓ Success! Guest user created: ${ctx.userId}'),
  );

  // ===== Example 3: Switch Pattern - Predicate Matching =====
  print('\n\n--- Example 3: Switch Pattern - Email Domain Routing ---');

  print('\n3.1 Government email (.gov):');
  final result7 = await createUserWithEmailDomainRouting('admin@agency.gov', 'GovPass123!');
  result7.fold(
    (error) => print('   ✗ Error: $error'),
    (ctx) => print('   ✓ Success! Gov user created: ${ctx.userId}'),
  );

  print('\n3.2 Example domain:');
  final result8 = await createUserWithEmailDomainRouting('test@example.com', 'TestPass123!');
  result8.fold(
    (error) => print('   ✗ Error: $error'),
    (ctx) => print('   ✓ Success! Example user created: ${ctx.userId}'),
  );

  print('\n3.3 Regular domain:');
  final result9 = await createUserWithEmailDomainRouting('user@company.io', 'CompanyPass123!');
  result9.fold(
    (error) => print('   ✗ Error: $error'),
    (ctx) => print('   ✓ Success! Regular user created: ${ctx.userId}'),
  );

  print('\n=== All examples complete ===');
}

// Context definition
final class CreateUserContext {
  final String email;
  final String password;
  final String? userId;
  final bool? emailVerified;
  final UserType? userType;

  const CreateUserContext({
    required this.email,
    required this.password,
    this.userId,
    this.emailVerified,
    this.userType,
  });

  CreateUserContext copyWith({String? userId, bool? emailVerified, UserType? userType}) {
    return CreateUserContext(
      email: email,
      password: password,
      userId: userId ?? this.userId,
      emailVerified: emailVerified ?? this.emailVerified,
      userType: userType ?? this.userType,
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

// User type for routing examples
enum UserType { admin, user, guest }

// Guards - Validation without mutation (note <E, C> order)
class EmailValidationGuard implements RailwayGuard<CreateUserError, CreateUserContext> {
  @override
  Future<Either<CreateUserError, void>> check(CreateUserContext context) async {
    if (!context.email.contains('@') || !context.email.contains('.')) {
      return const Left(CreateUserError.invalidEmail);
    }
    return const Right(null);
  }
}

class PasswordStrengthGuard implements RailwayGuard<CreateUserError, CreateUserContext> {
  @override
  Future<Either<CreateUserError, void>> check(CreateUserContext context) async {
    if (context.password.length < 8) {
      return const Left(CreateUserError.weakPassword);
    }
    return const Right(null);
  }
}

// Steps - State mutation with context updates (note <E, C> order)
class CreateUserStep extends RailwayStep<CreateUserError, CreateUserContext> {
  @override
  Future<Either<CreateUserError, CreateUserContext>> run(CreateUserContext context) async {
    // Simulate user creation
    await Future<void>.delayed(const Duration(milliseconds: 100));

    // Generate user ID
    final userId = 'user_${DateTime.now().millisecondsSinceEpoch}';

    return Right(context.copyWith(userId: userId));
  }
}

class SendVerificationEmailStep extends RailwayStep<CreateUserError, CreateUserContext> {
  @override
  Future<Either<CreateUserError, CreateUserContext>> run(CreateUserContext context) async {
    // Simulate sending email
    await Future.delayed(const Duration(milliseconds: 100));

    return Right(context.copyWith(emailVerified: true));
  }
}

// Additional steps for routing examples
class GrantAdminPermissionsStep extends RailwayStep<CreateUserError, CreateUserContext> {
  @override
  Future<Either<CreateUserError, CreateUserContext>> run(CreateUserContext context) async {
    print('   → Granting admin permissions to ${context.userId}');
    return Right(context);
  }
}

class SetupUserDashboardStep extends RailwayStep<CreateUserError, CreateUserContext> {
  @override
  Future<Either<CreateUserError, CreateUserContext>> run(CreateUserContext context) async {
    print('   → Setting up user dashboard for ${context.userId}');
    return Right(context);
  }
}

class CreateGuestSessionStep extends RailwayStep<CreateUserError, CreateUserContext> {
  @override
  Future<Either<CreateUserError, CreateUserContext>> run(CreateUserContext context) async {
    print('   → Creating limited guest session');
    return Right(context);
  }
}

// ============================================================================
// Example 1: Basic Railway with Guards and Steps
// ============================================================================
// Build and execute the railway (note <E, C> type parameter order)
Future<Either<CreateUserError, CreateUserContext>> createUser(
  String email,
  String password,
) async {
  final railway = const Railway<CreateUserError, CreateUserContext>()
      .guard(EmailValidationGuard())
      .guard(PasswordStrengthGuard())
      .step(CreateUserStep())
      .step(SendVerificationEmailStep());

  final initialContext = CreateUserContext(email: email, password: password);

  return await railway.run(initialContext);
}

// ============================================================================
// Example 2: Switch Pattern - User Type Routing
// ============================================================================
// This demonstrates using switchOn() for exclusive choice routing based on
// user type. Each case can have different workflow steps.
Future<Either<CreateUserError, CreateUserContext>> createUserWithTypeRouting(
  String email,
  String password,
  UserType userType,
) async {
  final railway = const Railway<CreateUserError, CreateUserContext>()
      .guard(EmailValidationGuard())
      .guard(PasswordStrengthGuard())
      .step(CreateUserStep())
      // Switch on user type for role-specific workflows
      .switchOn<UserType>((ctx) => userType)
      .when(UserType.admin, (r) => r.step(GrantAdminPermissionsStep()).step(SendVerificationEmailStep()))
      .when(UserType.user, (r) => r.step(SetupUserDashboardStep()).step(SendVerificationEmailStep()))
      .when(UserType.guest, (r) => r.step(CreateGuestSessionStep()))
      .end(); // No otherwise = no-op if no match

  final initialContext = CreateUserContext(
    email: email,
    password: password,
    userType: userType,
  );

  return await railway.run(initialContext);
}

// ============================================================================
// Example 3: Switch Pattern - Predicate Matching
// ============================================================================
// This demonstrates using whenMatch() for conditional routing based on
// dynamic predicates rather than exact value matching.
Future<Either<CreateUserError, CreateUserContext>> createUserWithEmailDomainRouting(
  String email,
  String password,
) async {
  final railway = const Railway<CreateUserError, CreateUserContext>()
      .guard(EmailValidationGuard())
      .guard(PasswordStrengthGuard())
      .step(CreateUserStep())
      // Route based on email domain
      .switchOn<String>((ctx) => ctx.email.split('@').last)
      .whenMatch(
        (domain) => domain.endsWith('.gov') || domain.endsWith('.edu'),
        (r) => r.step(GrantAdminPermissionsStep()),
      )
      .whenMatch(
        (domain) => domain.contains('example'),
        (r) => r.step(CreateGuestSessionStep()),
      )
      .otherwise((r) => r.step(SetupUserDashboardStep()))
      .step(SendVerificationEmailStep());

  final initialContext = CreateUserContext(email: email, password: password);

  return await railway.run(initialContext);
}
