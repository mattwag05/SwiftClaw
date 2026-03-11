---
name: swiftclaw-release
description: Build SwiftClaw release binary and validate it with the MLX metallib. Run this before testing the MLX backend. Handles the multi-step release workflow including metallib discovery and copy.
disable-model-invocation: true
---

Build the SwiftClaw release binary and set up the MLX metallib.

## Steps

1. Build release binary:
   ```
   swift build -c release
   ```

2. Find the mlx metallib. Check common locations:
   - Any `.metallib` files already in `.build/release/`
   - `/tmp/mlx-metallib/mlx/` (from a previous pip install)
   - Run `find /tmp -name "mlx.metallib" 2>/dev/null` to locate it

3. If not found, get the mlx version from the resolved dependencies:
   ```
   swift package show-dependencies 2>/dev/null | grep mlx-swift
   ```
   Then install: `pip install --target /tmp/mlx-metallib mlx==<version> --quiet`

4. Copy the metallib:
   ```
   cp /tmp/mlx-metallib/mlx/mlx.metallib .build/release/
   ```

5. Verify:
   ```
   .build/release/swiftclaw doctor
   ```

Report success or any errors at each step.
