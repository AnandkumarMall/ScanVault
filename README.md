# ScanVault

A fast, lightweight, **fully-offline** document scanner for Android. Scan or
import images → detect edges → crop/enhance → manage multi-page documents →
export & share as PDF. **No login, no cloud, no account.**

Your documents live in a folder **you** choose (the "Vault"), so they survive
uninstall. See [`PLAN.md`](PLAN.md) for the full design.

---

## Status

| Phase | Scope | State |
|-------|-------|-------|
| 0 | Toolchain (Flutter 3.38+, Android SDK, FVM) | ⏳ user-installed manually |
| 1 | Scaffold + Vault (SAF connect, atomic writes, rebuildable index, home grid) | ✅ code scaffolded |
| 2 | Capture / import | ⬜ |
| 3 | Detect & crop (OpenCV) | ⬜ |
| 4 | Enhance / filters | ⬜ |
| 5 | Multi-page management | ⬜ |
| 6 | PDF export/import + share | ⬜ |
| 7 | Polish + APK-size hardening | ⬜ |

**Locked decisions:** package `com.scanvault.app` · minSdk 26 (Android 8) ·
compile/target SDK 35 · emulator testing (include `x86_64` ABI in debug).

---

## Phase 0 — one-time environment setup (you run these)

Nothing is installed yet except Git + Java 11. You need:

1. **JDK 17** (Flutter's Android toolchain needs 17, not 11).
2. **Flutter 3.38+** — install the SDK and add it to `PATH`.
3. **Android SDK** — via Android Studio or `cmdline-tools`. Install:
   `platform-tools`, `build-tools;35.0.0`, `platforms;android-35`, and an
   emulator system image **with `x86_64`** (OpenCV needs it), then accept
   licenses: `flutter doctor --android-licenses`.
4. **FVM** (optional but recommended) to pin Flutter per project:
   `dart pub global activate fvm` then `fvm use 3.38.0` (already pinned in
   `.fvmrc`).
5. Set `DARTCV_CACHE_DIR` to a stable path so the OpenCV SDK downloads once.
6. Verify: `flutter doctor -v` — resolve all ✗.

## Generate the Android platform folder

`lib/` and `pubspec.yaml` are already written. Generate the missing `android/`
scaffold **without clobbering** the code (commit first — this repo is git-init'd):

```bash
git add -A && git commit -m "scaffold before flutter create"   # safety net
flutter create --org com.scanvault --project-name scanvault --platforms=android .
git checkout -- pubspec.yaml            # keep OUR pubspec (deps + dartcv hooks)
flutter pub get
```

Then apply the Android tweaks (Claude will do these once the folder exists):
- `android/app/build.gradle`: `minSdkVersion 26`, `targetSdk 35`,
  `applicationId "com.scanvault.app"`, release `minifyEnabled true` +
  `shrinkResources true`.
- No SAF permission is needed in the manifest — the folder picker grants access.
  Camera permission is added in Phase 2.

## Run

```bash
flutter run                    # on emulator (x86_64) or USB device
flutter test                   # pure-Dart unit tests (no device needed)
```

## Build (size-conscious — PLAN.md §7)

```bash
flutter build apk --release --split-per-abi \
  --obfuscate --split-debug-info=./debug-info
# target: < 25 MB per-ABI APK — measure with:
flutter build apk --release --analyze-size --target-platform android-arm64
```

---

## Project layout

```
lib/
  main.dart                       # entry: load prefs → ProviderScope
  src/
    app/        constants, providers (Riverpod), theme, root gate
    core/       json_utils, failure (typed VaultFailure)
    domain/models/  Document, DocPage, EditParams, IndexEntry, VaultConfig
    data/vault/     SafGateway (SAF I/O + atomic writes), VaultRepository,
                    VaultPrefs, VaultLayout
    features/
      onboarding/   ConnectScreen, ReconnectScreen
      home/         HomeScreen (document grid)
```
