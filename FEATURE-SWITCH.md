# Feature Request: Switch/Router Pattern

## Problem Statement

Currently, `branch()` allows conditional execution of a single path based on a predicate. However, when you need **mutually exclusive routing** based on context state (e.g., different workflows for different age groups, user types, or status values), the current approach has limitations:

**Current approach with chained branches:**
```dart
Railway<Error, UserContext>()
  .step(ValidateUser())
  .branch((ctx) => ctx.age == 10, (r) => r
      .step(ProcessChildConsent())
      .step(ApplyChildPricing()))
  .branch((ctx) => ctx.age == 20, (r) => r
      .step(VerifyYoungAdultID())
      .step(YoungAdultWorkflow()))
  .branch((ctx) => ctx.age == 50, (r) => r
      .step(MiddleAgeHealthCheck())
      .step(MiddleAgeWorkflow()))
  .branch((ctx) => ctx.isDead, (r) => r
      .step(NotifyNextOfKin())
      .step(ProcessEstate()))
  .step(ContinueWorkflow())
```

**Problems:**
- ❌ All predicates evaluate even after a match is found
- ❌ Multiple branches can execute if multiple conditions are true
- ❌ No explicit default/fallback case
- ❌ Verbose when you have many cases
- ❌ Intent unclear - are these independent conditions or exclusive choices?

## Proposed Solution

Add a `switch()` method for **exclusive choice routing** where exactly one path executes.

### Design Considerations

**Option 1: Map-based switch (explicit keys)**
```dart
Railway<Error, UserContext>()
  .step(ValidateUser())
  .switch(
    selector: (ctx) => ctx.userType,
    cases: {
      UserType.child: (r) => r
          .step(VerifyParentalConsent())
          .step(ApplyChildPricing())
          .step(ProcessChildOrder()),
      UserType.adult: (r) => r
          .step(VerifyIdentity())
          .step(StandardPricing())
          .step(ProcessOrder()),
      UserType.senior: (r) => r
          .step(ApplySeniorDiscount())
          .step(OfferAssistance())
          .step(ProcessOrder()),
    },
    defaultCase: (r) => r.step(GuestCheckout()), // Optional
  )
```

**Option 2: Pattern-matching style**
```dart
Railway<Error, UserContext>()
  .step(ValidateUser())
  .switchOn((ctx) => ctx.age)
    .when(0..18, (r) => r
        .step(RequireParentalConsent())
        .step(MinorPricing())
        .step(ProcessMinorOrder()))
    .when(19..64, (r) => r
        .step(StandardPricing())
        .step(ProcessOrder()))
    .when(65..120, (r) => r
        .step(SeniorDiscount())
        .step(ProcessOrder()))
    .otherwise((r) => r.step(DefaultCheckout()))
```

**Option 3: Custom routing step (current workaround)**
```dart
// Keep routing logic in a custom step to avoid polluting Railway API
// Each case can execute a FULL SUB-ROUTINE with multiple steps
class UserTypeRouter extends RailwayStep<Error, UserContext> {
  @override
  Future<Either<Error, UserContext>> run(UserContext ctx) async {
    return switch (ctx.userType) {
      UserType.child => await _childWorkflow(ctx),      // Can have many steps
      UserType.adult => await _adultWorkflow(ctx),      // Can have many steps
      UserType.senior => await _seniorWorkflow(ctx),    // Can have many steps
      _ => await _defaultWorkflow(ctx),
    };
  }
  
  // Each workflow can be a complete Railway with multiple steps
  Future<Either<Error, UserContext>> _childWorkflow(UserContext ctx) async {
    return Railway<Error, UserContext>()
        .step(ValidateAge())
        .step(ApplyChildDiscount())
        .step(RequireParentalConsent())
        .step(ProcessChildOrder())
        .run(ctx);
  }
  
  Future<Either<Error, UserContext>> _adultWorkflow(UserContext ctx) async {
    return Railway<Error, UserContext>()
        .step(VerifyIdentity())
        .step(CheckCreditHistory())
        .step(ProcessStandardOrder())
        .run(ctx);
  }
  
  // ... other workflows with multiple steps each
}

Railway<Error, UserContext>()
  .step(ValidateUser())
  .step(UserTypeRouter())  // Routes to multi-step sub-workflows
  .step(ContinueWorkflow())
```

## Recommended Approach

**Option 2 (Pattern-Matching Style)** is recommended because:
- ✅ Fluent, declarative API that reads naturally
- ✅ Clear intent - this is routing/switching logic
- ✅ Each case can contain multiple steps (full sub-workflows)
- ✅ Type-safe with compile-time case checking
- ✅ Short-circuits after first match
- ✅ Explicit `otherwise()` for default case
- ✅ Stays within the Railway builder pattern (no nested Railway instances)
- ✅ All cases participate in the main compensation stack

**Option 1 is acceptable** but less ergonomic due to map syntax.

**Option 3 is NOT a switch** - it's actually a sub-routine pattern (see below).

## Open Questions

1. **Compensation**: How do compensations work with switch cases?
   - Only the executed case's steps should compensate
   - The switch itself doesn't need compensation (it's routing logic)

2. **Error handling**: What if the selector function throws?
   - Should probably propagate as Left(error)
   - Or require selector to be pure and catch exceptions

3. **Type safety**: Can we preserve type narrowing in each case?
   - Dart's type system might make this challenging
   - All cases must return same `Railway<C, E>` type

4. **Nested routing**: Should switch cases allow further nesting?
   - Yes, cases return railway builders so they can contain anything
   - Including other switches for multi-level routing

## Examples

### Use Case: Order Processing by Customer Type
```dart
Railway<OrderError, OrderContext>()
  .step(ValidateOrder())
  .switchOn((ctx) => ctx.customerTier)
    .when(Tier.platinum, (r) => r
        .step(ValidatePlatinumStatus())
        .step(ApplyPlatinumDiscount())
        .step(AddComplimentaryUpgrades())
        .step(PriorityShipping())
        .step(AssignDedicatedSupport())
        .step(SendPersonalizedThankYou()))
    .when(Tier.gold, (r) => r
        .step(ApplyGoldDiscount())
        .step(ExpressShipping())
        .step(PrioritySupport()))
    .when(Tier.silver, (r) => r
        .step(ApplySilverDiscount())
        .step(StandardShipping()))
    .when(Tier.bronze, (r) => r
        .step(StandardPricing())
        .step(StandardShipping()))
    .otherwise((r) => r.step(GuestCheckout()))
  .step(FinalizeOrder())
  .step(SendConfirmation())
```

### Use Case: Document Status Workflow
```dart
Railway<DocError, DocContext>()
  .step(LoadDocument())
  .switchOn((ctx) => ctx.status)
    .when(Status.draft, (r) => r
        .step(ValidateDraft())
        .step(SaveDraft()))
    .when(Status.pending, (r) => r
        .step(AssignReviewer())
        .step(NotifyReviewerByEmail())
        .step(CreateReviewTask())
        .step(SetReviewDeadline()))
    .when(Status.approved, (r) => r
        .step(ValidateDocumentFormat())
        .step(GeneratePDF())
        .step(UploadToRepository())
        .step(NotifySubscribers())
        .step(UpdateSearchIndex()))
    .when(Status.rejected, (r) => r
        .step(NotifyAuthor())
        .step(MoveToArchive())
        .step(UpdateAuditLog()))
    .otherwise((r) => r.step(LogUnknownStatus()))
  .step(UpdateTimestamp())
```

### Use Case: Age-Based User Registration
```dart
Railway<UserError, UserContext>()
  .step(ValidateBasicInfo())
  .switchOn((ctx) => ctx.age)
    .when(0..12, (r) => r
        .step(RequireParentEmail())
        .step(SendParentConsentRequest())
        .step(CreateChildAccount())
        .step(EnableParentalControls()))
    .when(13..17, (r) => r
        .step(RequireParentEmail())
        .step(CreateTeenAccount())
        .step(ApplyAgeRestrictions()))
    .when(18..64, (r) => r
        .step(CreateStandardAccount())
        .step(EnableAllFeatures()))
    .when(65..120, (r) => r
        .step(CreateSeniorAccount())
        .step(EnableAccessibilityFeatures())
        .step(OfferAssistanceProgram()))
    .otherwise((r) => r.step(RejectInvalidAge()))
  .step(SendWelcomeEmail())
  .step(LogRegistration())
```

## Decision

**Recommendation**: Implement **Option 2** (Pattern-Matching Style) as the idiomatic way to handle switching/routing in Railway workflows.

---

## Switch vs Sub-Routine Pattern

### Switch (Option 1 & 2)
**Definition**: Routing logic that stays **within the Railway builder** - all cases are part of the same railway instance and share the same compensation stack.

```dart
Railway<Error, UserContext>()
  .step(ValidateUser())
  .switchOn((ctx) => ctx.age)
    .when(0..18, (r) => r.step(MinorStep1()).step(MinorStep2()))
    .when(19..64, (r) => r.step(AdultStep1()).step(AdultStep2()))
    .otherwise((r) => r.step(DefaultStep()))
  .step(ContinueMainFlow())
```

**Characteristics:**
- ✅ One Railway instance
- ✅ One compensation stack (all cases participate)
- ✅ Declarative routing at the railway level
- ✅ Exactly one case executes (mutually exclusive)

### Sub-Routine (Option 3)
**Definition**: A step that **starts a new Railway instance** internally - creates a separate execution context.

```dart
class UserTypeRouter extends RailwayStep<Error, UserContext> {
  @override
  Future<Either<Error, UserContext>> run(UserContext ctx) async {
    return switch (ctx.userType) {
      UserType.child => await Railway<Error, UserContext>()  // NEW Railway!
          .step(ChildStep1())
          .step(ChildStep2())
          .run(ctx),
      // ...
    };
  }
}
```

**Characteristics:**
- ⚠️ Creates new Railway instances (nested execution)
- ⚠️ Separate compensation stacks per case
- ⚠️ Sub-routine compensations are isolated from main railway
- ⚠️ More complex to reason about (nested context)

**Why Sub-Routines are Different:**
- Each case gets its own Railway execution with isolated error handling
- If a sub-routine fails and compensates, the main railway doesn't see those compensations
- Useful for fully independent workflows, but NOT for routing within a pipeline

**Use Sub-Routines When:**
- You need completely isolated error handling per case
- Each case is a standalone workflow with its own transaction boundary
- Cases should not participate in the parent railway's compensation

**Use Switch When:**
- You're routing within a single workflow
- All cases should participate in the same compensation chain
- You want declarative, readable route definitions

---

## Implementation Design (Option 2)

### API Surface

```dart
class Railway<E, C> {
  // Returns a SwitchBuilder that captures the selector function
  SwitchBuilder<E, C, T> switchOn<T>(T Function(C) selector);
}

class SwitchBuilder<E, C, T> {
  // Add a case with value equality match
  SwitchBuilder<E, C, T> when(
    T value,
    Railway<E, C> Function(Railway<E, C>) builder,
  );
  
  // Add a case with a predicate function  
  SwitchBuilder<E, C, T> whenMatch(
    bool Function(T) predicate,
    Railway<E, C> Function(Railway<E, C>) builder,
  );
  
  // Fallback case (optional, returns Railway)
  Railway<E, C> otherwise(Railway<E, C> Function(Railway<E, C>) builder);
  
  // If no otherwise specified, return the builder as Railway (passthrough)
  Railway<E, C> end();
}
```

### Usage Examples

```dart
// Simple value matching
Railway<Error, Context>()
  .switchOn((ctx) => ctx.status)
    .when(Status.active, (r) => r.step(ProcessActive()))
    .when(Status.inactive, (r) => r.step(ProcessInactive()))
    .otherwise((r) => r.step(HandleUnknown()))

// Predicate matching (for ranges, complex conditions)
Railway<Error, Context>()
  .switchOn((ctx) => ctx.age)
    .whenMatch((age) => age >= 0 && age <= 17, (r) => r.step(MinorFlow()))
    .whenMatch((age) => age >= 18 && age <= 64, (r) => r.step(AdultFlow()))
    .whenMatch((age) => age >= 65, (r) => r.step(SeniorFlow()))
    .end()  // No otherwise - passthrough if no match

// Grading example
Railway<Error, Context>()
  .switchOn((ctx) => ctx.score)
    .whenMatch((score) => score >= 90, (r) => r.step(AssignGradeA()))
    .whenMatch((score) => score >= 80, (r) => r.step(AssignGradeB()))
    .whenMatch((score) => score >= 70, (r) => r.step(AssignGradeC()))
    .whenMatch((score) => score >= 60, (r) => r.step(AssignGradeD()))
    .otherwise((r) => r.step(AssignGradeF()))
```

### Internal Behavior

1. `switchOn()` captures the selector function and returns a `SwitchBuilder`
2. Each `when()` or `whenMatch()` adds a case to an internal list
3. `otherwise()` or `end()` finalizes the builder and returns a Railway
4. At runtime:
   - Selector is evaluated **once** with current context
   - Cases are checked in order until first match found
   - Matched case's builder function adds operations to the railway
   - If no match and no otherwise, context passes through unchanged
5. All matched case operations are part of the main railway's operation list
6. Compensation stack includes all executed operations from the matched case

### Key Benefits

- **One railway instance**: No nested Railway.run() calls
- **Shared compensation stack**: All switch cases participate in rollback
- **Declarative**: Routing is visible in the railway definition
- **Type-safe**: Compile-time checking of types
- **Exclusive**: Exactly one case executes (short-circuit on first match)

---

**Status**: Proposed for Implementation  
**Priority**: Medium (common use case)  
**Complexity**: Medium  
**Recommendation**: Implement Option 2 (Pattern-Matching Style)
