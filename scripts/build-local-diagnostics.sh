#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
export PATH="$HOME/.cargo/bin:$PATH"
# Limit local memory use; CI may opt into more parallel compilation.
export CARGO_BUILD_JOBS="${CARGO_BUILD_JOBS:-1}"
revision=d32c8189c51c2789496b0768039419c3705498c3
root="$PWD/Build/local-diagnostics-source"
out="$PWD/Build/LocalDiagnostics"
if [[ ! -f "$root/.mochilog-revision" ]] || [[ "$(cat "$root/.mochilog-revision")" != "$revision" ]]; then
  mkdir -p "$root"
  curl --fail --location "https://api.github.com/repos/jkcoxson/idevice/tarball/$revision" | tar -xz --strip-components=1 -C "$root"
  printf '%s' "$revision" > "$root/.mochilog-revision"
fi
python3 scripts/patch-local-diagnostics.py "$root"
rustup target add aarch64-apple-ios aarch64-apple-ios-sim x86_64-apple-ios
mkdir -p "$out"
export IPHONEOS_DEPLOYMENT_TARGET=16.0
features=ring,tunnel_tcp_stack,remote_pairing,rsd,diagnostics_relay,crashreportcopymobile
for target in aarch64-apple-ios aarch64-apple-ios-sim x86_64-apple-ios; do
  cargo build --locked --manifest-path "$root/Cargo.toml" -p idevice-ffi --no-default-features --features "$features" --target "$target" --release
  mkdir -p "$out/$target/Headers"
  cp "$root/target/$target/release/libidevice_ffi.a" "$out/$target/"
  cp "$root/ffi/idevice.h" "$out/$target/Headers/"
  printf 'module idevice { header "idevice.h" export * }\n' > "$out/$target/Headers/module.modulemap"
done
mkdir -p "$out/simulator"
lipo -create "$out/aarch64-apple-ios-sim/libidevice_ffi.a" "$out/x86_64-apple-ios/libidevice_ffi.a" -output "$out/simulator/libidevice_ffi.a"
if [[ -d "$out/idevice.xcframework" ]]; then rm -r "$out/idevice.xcframework"; fi
xcodebuild -create-xcframework -library "$out/aarch64-apple-ios/libidevice_ffi.a" -headers "$out/aarch64-apple-ios/Headers" -library "$out/simulator/libidevice_ffi.a" -headers "$out/aarch64-apple-ios-sim/Headers" -output "$out/idevice.xcframework"
python3 scripts/local-diagnostics-licenses.py "$root" "$features"
