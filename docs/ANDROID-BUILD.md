# Building for Android

`flutter/README.md` documents the upstream Android build: the Linux engine cross-compiled for
arm64, the codecs as static libraries, FFmpeg as shared ones, and the Flutter editor around it.
It assumes a machine where all of that is already set up. This document is about the CI that
does it from nothing, and about what is still unproven.

## What runs

`.github/workflows/android.yml`, three jobs:

| Job | Does | Cold | Cached |
| --- | --- | --- | --- |
| `halide` | The pinned Halide submodule with the five Vulkan patches, built against LLVM 21 | 1–2 h | seconds |
| `codecs` | LibRaw, lcms2, libjpeg-turbo, libpng, libtiff, libheif + libde265, Imath, OpenEXR, FFmpeg — all for arm64-v8a | 20–40 min | seconds |
| `android` | JDK 17, NDK r30, Flutter, the swift.org toolchain and its Android SDK, then the engine and the app | 15–25 min | 15–25 min |

`halide` and `codecs` run in parallel. The caches key on the Halide pin plus the patch set, and on
the codec script plus the NDK release, so they only rebuild when those actually change.

## Versions, and why these ones

- **Swift 6.3.3** — `tools/build-android-engine.sh` defaults to `swift-6.3.3-RELEASE`. A Swift SDK
  only works with the exact toolchain release it was built for, and Xcode's Swift cannot read it,
  so the toolchain comes from swift.org.
- **Swift SDK for Android** — `swift-6.3.3-RELEASE_android.artifactbundle`, from
  `download.swift.org`. The bundle carries that name itself, which is what the engine script
  expects under `~/.swiftpm/swift-sdks/`.
- **NDK r30 (LTS)** — the Swift SDK for Android is built against NDK LTS r30, so one NDK serves the
  codecs, the engine and Gradle. `flutter/android/app/build.gradle.kts` reads
  `FOTUFILM_ANDROID_NDK_VERSION` so Gradle agrees with the rest instead of using Flutter's default.
- **LLVM 21** — Halide needs LLVM, Clang and LLD 21 or newer with their CMake files. The Android
  job keeps LLVM installed because the AOT generator loads `libHalide.so`, which links `libLLVM`.
- **Flutter 3.41.7** — the version upstream CI pins; `pubspec.yaml` needs Dart `^3.11.5`.

## Verified before the first run

- The Swift 6.3.3 Ubuntu 24.04 toolchain tarball resolves (HTTP 200).
- The Swift SDK for Android bundle resolves (HTTP 200, 333 MB).
- `apt.llvm.org/noble` carries `llvm-toolchain-noble-21`.
- `flutter/android/` already builds a Flutter app: `minSdk 28`, `arm64-v8a` only, no manifest
  permissions at all, photographs through the Storage Access Framework.

## Unproven — expect these on the first run

Ordered by how likely they are to bite:

1. **Halide against LLVM 21.** The patches are written for the pinned Halide; a moved LLVM can
   shift an API. This is the step most likely to fail, and the one worth fixing first.
2. **NDK r30 against the codec script.** It was written against the NDK Flutter ships. r30 is
   newer; a configure flag or a removed header is plausible.
3. **`libHalide.so` at AOT time.** If the generator cannot find it, `LD_LIBRARY_PATH` is wrong.
4. **The bundle-path audit.** `flutter/build-android.sh` greps the APK for build folder paths and
   fails the build if it finds one. On a runner, `$HOME` is `/home/runner`, which is a short and
   greppable string. If this trips, it is a false positive in their guard, not a real leak.
5. **`tool/prepare.sh`** stages glyphs and fonts, and the fonts come from Fontshare over the
   network. A failed fetch there stops the build.

## Running it

Actions → **Android** → *Run workflow* → `apk` for a phone, `appbundle` for Play. The package lands
in the `fotufilm-android` artifact. Without `FOTUFILM_ANDROID_KEYSTORE` the APK is debug-signed,
which is what a first phone check wants; an AAB for Play needs a real keystore.
