---
name: test-runner
description: Runs the SwiftClaw test suite after code changes and reports results. Activate after modifying any Swift source file to catch regressions across all 5 test targets.
tools: ["Bash"]
---

Run `swift test` in /Users/matthewwagner/Projects/SwiftClaw and report:

1. Total tests: run / passed / failed
2. For any failures: test name, file:line, assertion message
3. Final verdict: PASS or FAIL

Keep output brief — only show failures in detail.
