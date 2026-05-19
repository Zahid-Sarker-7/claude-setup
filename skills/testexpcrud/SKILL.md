---
name: testexpcrud
description: Comprehensive functional testing of opal-tools experimentation CRUD features. Analyzes chat conversation and plan context to generate test scenarios. Use --before to baseline, --after to verify fixes.
argument-hint: "--before|--after <token> [project_id]"
disable-model-invocation: true
---

# Test Experimentation CRUD Tools

Functional testing of opal-tools experimentation CRUD features with hot reload.

**Two modes:**
- `--before` — Baseline before development. Tests may fail — that's expected.
- `--after` — Verify after development. All tests should pass.

## Usage

```
/testexpcrud --before eyJhbGci...          # baseline before development
/testexpcrud --after eyJhbGci...           # verify after development
/testexpcrud --before eyJhbGci... 5129532268085248   # FX project
```

## Steps

1. Parse arguments (mode, token, optional project_id)
2. Analyze conversation context to generate feature-specific test scenarios
3. Rename tool decorators for conflict-free testing
4. Start development environment (build TS backend, health check)
5. Execute comprehensive test scenarios (positive, negative, edge cases, regression)
6. Document test results with before/after comparison
7. Revert tool name changes

See the full SKILL.md for detailed test patterns, auth formats, and known pitfalls.
