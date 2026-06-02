#!/usr/bin/env bash
#
# Run SwiftClaw's CI inside an ephemeral, isolated macOS VM (Tart + a Cirrus
# Labs macOS+Xcode image). Mirrors the gates in .github/workflows/ci.yml
# (`swift build` + `swift test --parallel`) but runs locally on Apple Silicon
# with **zero GitHub-hosted minutes** and **no listening self-hosted runner**
# (so this public repo is never exposed to forked-PR code execution). Each run
# clones a fresh VM from the base image, rsyncs the working tree in, runs
# build/test, then destroys the VM.
#
# One-time setup (shared with pippin — the base image is a generic macOS+Xcode VM):
#   brew install cirruslabs/cli/tart hudochenkov/sshpass/sshpass
#   tart clone ghcr.io/cirruslabs/macos-sequoia-xcode:latest pippin-ci-base
#
# Usage: scripts/ci-vm.sh    (or: make ci-vm)
#
# Env overrides:
#   SWIFTCLAW_CI_BASE   base image name   (default: pippin-ci-base, the shared image)
#   SWIFTCLAW_CI_VM     ephemeral VM name (default: swiftclaw-ci-run)

set -euo pipefail

BASE="${SWIFTCLAW_CI_BASE:-pippin-ci-base}"
VM="${SWIFTCLAW_CI_VM:-swiftclaw-ci-run}"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VM_USER="admin"
VM_PASS="admin" # Cirrus image default credentials; the VM is ephemeral.

log() { printf '\033[1;34m[ci-vm]\033[0m %s\n' "$*"; }
die() {
    printf '\033[1;31m[ci-vm] ERROR:\033[0m %s\n' "$*" >&2
    exit 1
}

command -v tart >/dev/null 2>&1 || die "tart not installed — brew install cirruslabs/cli/tart"
command -v sshpass >/dev/null 2>&1 || die "sshpass not installed — brew install hudochenkov/sshpass/sshpass"

if ! tart list 2>/dev/null | awk '{print $2}' | grep -qx "$BASE"; then
    die "base image '$BASE' not found. Pull it once with:
  tart clone ghcr.io/cirruslabs/macos-sequoia-xcode:latest $BASE"
fi

VM_PID=""
cleanup() {
    [ -n "$VM_PID" ] && kill "$VM_PID" 2>/dev/null || true
    tart delete "$VM" 2>/dev/null || true
    log "ephemeral VM '$VM' destroyed"
}
trap cleanup EXIT

log "cloning ephemeral VM '$VM' from '$BASE'"
tart delete "$VM" 2>/dev/null || true
tart clone "$BASE" "$VM"

log "booting VM (headless)"
tart run --no-graphics "$VM" >/dev/null 2>&1 &
VM_PID=$!

log "waiting for VM IP"
IP=""
for _ in $(seq 1 90); do
    IP="$(tart ip "$VM" 2>/dev/null || true)"
    [ -n "$IP" ] && break
    sleep 2
done
[ -n "$IP" ] || die "VM never reported an IP"
log "VM IP: $IP"

# Force password-only auth: without this, ssh offers every agent/identity key
# first and trips the VM sshd's MaxAuthTries ("Too many authentication
# failures") before sshpass ever sends the password.
SSH_OPTS="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR -o PreferredAuthentications=password -o PubkeyAuthentication=no -o IdentitiesOnly=yes -o NumberOfPasswordPrompts=1"
ssh_vm() { sshpass -p "$VM_PASS" ssh $SSH_OPTS "$VM_USER@$IP" "$@"; }

log "waiting for sshd"
for _ in $(seq 1 60); do ssh_vm true 2>/dev/null && break; sleep 2; done
ssh_vm true 2>/dev/null || die "SSH never came up in the VM"

log "syncing working tree into VM (excluding .build/.git)"
ssh_vm 'rm -rf ~/SwiftClaw && mkdir -p ~/SwiftClaw'
sshpass -p "$VM_PASS" rsync -a --delete \
    --exclude '.build' --exclude '.git' \
    -e "ssh $SSH_OPTS" "$REPO_ROOT/" "$VM_USER@$IP:SwiftClaw/"

log "running CI steps inside the VM (mirrors ci.yml)"
# Non-interactive ssh gets a minimal PATH (no ~/.zprofile); add Homebrew for parity.
ssh_vm 'set -euo pipefail; export PATH="/opt/homebrew/bin:$PATH"; cd ~/SwiftClaw
    echo "== toolchain =="; xcrun --sdk macosx swift --version | head -1
    echo "== build (debug) =="; xcrun --sdk macosx swift build
    echo "== test =="; xcrun --sdk macosx swift test --parallel'

log "CI passed in isolated VM ✅"
