#!/bin/bash

# Ensure that `cargo` is in PATH, using the default location.
export PATH="$PATH:${HOME}/.cargo/bin"
export OPENSSL_DIR="/usr/local/opt/openssl"

set -x

# Go to repo's root
cd "${SRCROOT}/../"

# Build binaries
RUSTFLAGS="-Z embed-bitcode" cargo +ios-arm64 build --target aarch64-apple-ios --release --lib
cargo build --target=x86_64-apple-ios --release

# Create fat binary
libtool -static -o ./ios_app/core/libcore ./target/aarch64-apple-ios/release/libcore.a ./target/x86_64-apple-ios/release/libcore.a

cbindgen --config cbindgen.toml --crate libcore --output ios_app/core/mobileapp-ios.h
