## Why

Application-layer workflows currently lack a clean, strongly-typed orchestration model that separates validation from state mutation while maintaining declarative readability. This package provides a railway-oriented programming pattern for Dart that ensures predictable error handling, type safety, and UX-focused workflow control in Clean Architecture/DDD systems.

## What Changes

- Introduce a new standalone Dart package `gradis` for application-layer workflow orchestration
- Provide strongly-typed, immutable context propagation through workflow pipelines
- Implement builder-style railway with separate guard and step abstractions
- Enable declarative workflow definitions with automatic short-circuiting on first failure
- Support single unified error type per workflow (no runtime casting or Object-based errors)
- Allow workflows to own transaction boundaries without railway managing them

## Capabilities

### New Capabilities

- `workflow-core`: Core abstractions including WorkflowRailway builder, context propagation, guard/step contracts, and error handling model
- `workflow-guards`: Guard interface and patterns for validation without context mutation
- `workflow-steps`: Step interface and patterns for state mutation with context updates
- `workflow-execution`: Railway execution engine with short-circuit behavior and Either-based result handling

### Modified Capabilities

_None - this is a new package with no modifications to existing capabilities_

## Impact

- **New Package**: Creates `packages/gradis/` as a standalone Dart package
- **Dependencies**: Requires `either_dart` package for Either type
- **Application Layer**: Provides new orchestration pattern for use cases and workflows
- **Testing**: Requires comprehensive unit tests for guards, steps, and railway execution
- **Documentation**: Needs package README, API docs, and usage examples
- **Future Systems**: Will be used across application layer for complex multi-step workflows requiring validation and state mutation
