#!/bin/bash
set -euo pipefail

# Requires an x86-64 Linux host with git, make, rustup, Clang/libclang 14,
# gcc-arm-linux-gnueabihf and libc6-dev-armhf-cross. Install Rust
# nightly-2023-10-05 with the armv7-unknown-linux-gnueabihf target beforehand.
# Use the same REPO and TAG as download-crsqlite.sh for the other architectures.

if [[ -z "${REPO:-}" ]]; then
    echo "Set crsqlite repository owner with REPO env var" >&2
    exit 1
fi

if [[ -z "${TAG:-}" ]]; then
    echo "Set crsqlite tag with TAG env var" >&2
    exit 1
fi

git check-ref-format "refs/tags/$TAG"

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
workdir=$(mktemp -d)
trap 'rm -rf -- "$workdir"' EXIT

# The pinned source uses an SSH submodule URL; CI should not need SSH credentials.
git -c url.https://github.com/.insteadOf=git@github.com: \
    clone --depth 1 --branch "$TAG" --recurse-submodules \
    "https://github.com/${REPO}/cr-sqlite.git" "$workdir/source"
cd "$workdir/source"
echo "Building crsqlite for ARMv7 from $(git rev-parse HEAD)"

export CARGO_TARGET_ARMV7_UNKNOWN_LINUX_GNUEABIHF_LINKER=arm-linux-gnueabihf-gcc
export CC_armv7_unknown_linux_gnueabihf=arm-linux-gnueabihf-gcc
export AR_armv7_unknown_linux_gnueabihf=arm-linux-gnueabihf-ar
export CI_MAYBE_TARGET=armv7-unknown-linux-gnueabihf
export CI_GCC=arm-linux-gnueabihf-gcc
export LIBCLANG_PATH="${LIBCLANG_PATH:-/usr/lib/llvm-14/lib}"
# Match the output path expected by the upstream Makefile, regardless of CI env.
export CARGO_TARGET_DIR="$workdir/source/core/rs/bundle_static/target"

rustup run nightly-2023-10-05 make -C core loadable rs_build_flags=--locked

# Copy the extension only after a successful build.
output="$root/crates/corro-types/crsqlite-linux-armv7.so"
install -m 644 core/dist/crsqlite.so "$output"
sha256sum "$output"
