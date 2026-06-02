.PHONY: build test ci ci-vm

build:
	xcrun --sdk macosx swift build

test:
	xcrun --sdk macosx swift test --parallel

# Full CI gate run NATIVELY on this host (fast, no VM). Mirrors ci.yml.
ci:
	xcrun --sdk macosx swift build
	xcrun --sdk macosx swift test --parallel

# Full CI gate run inside an isolated, ephemeral macOS VM (Tart + Cirrus Xcode
# image) — local parity with the macos-15 GitHub runner, zero hosted minutes,
# no listening runner exposed to public fork PRs. One-time setup (shared image
# with pippin):
#   brew install cirruslabs/cli/tart hudochenkov/sshpass/sshpass
#   tart clone ghcr.io/cirruslabs/macos-sequoia-xcode:latest pippin-ci-base
ci-vm:
	@bash scripts/ci-vm.sh
