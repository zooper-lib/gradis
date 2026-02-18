## Why

Complex workflows often need error recovery and conditional execution paths. Currently, the Railway pattern only supports forward execution with short-circuit error handling. This limits its use in scenarios requiring rollback (compensating transactions) or conditional branching (different paths based on runtime state).

## What Changes

- Add `compensate` method to `RailwayStep` interface for reverse execution/cleanup when errors occur downstream
- Add `branch` method to `Railway` builder for conditional execution paths based on predicate evaluation
- Implement compensation tracking in Railway to maintain a compensation stack during execution
- Execute compensations in reverse order when pipeline encounters an error
- **BREAKING**: Modify `RailwayStep` interface to include optional `compensate` method

## Capabilities

### New Capabilities

- `workflow-compensation`: Compensation (reverse execution) support for error recovery and rollback scenarios. Defines how steps can register cleanup/undo operations that execute in reverse order when the pipeline fails.
- `workflow-branching`: Conditional branching support for workflow execution. Defines how the railway can evaluate predicates and execute different sub-pipelines based on context state.

### Modified Capabilities

_No existing capabilities are modified at the requirement level._

## Impact

**Affected Code:**
- `lib/src/railway_step.dart`: Add `compensate` method to interface (breaking change)
- `lib/src/railway.dart`: Add compensation tracking, add `branch` method, modify execution logic to handle compensations and branches

**Breaking Change:**
- Existing implementations of `RailwayStep` must add a `compensate` method (can be empty default implementation with `async {}`)

**Dependencies:**
- No new external dependencies required
- Uses existing `either_dart` package for Either monad
