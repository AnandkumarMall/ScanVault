# ScanVault

**A fast, lightweight, fully-offline document scanner for Android.**

> No login. No cloud. No account. Your documents never leave your device.

Scan or import images → auto-detect edges → crop & enhance → manage multi-page documents → export & share as PDF.

<p align="center">
  <img src="docs/screenshot-home.png" alt="Home screen" width="220"/>
  <img src="docs/screenshot-crop.png" alt="Crop review" width="220"/>
  <img src="docs/screenshot-enhance.png" alt="Enhance filters" width="220"/>
  <img src="docs/screenshot-doc.png" alt="Document detail" width="220"/>
</p>

---

## Why ScanVault?

| Feature | What it means for you |
|---------|----------------------|
| **💾 Local-first & private** | Nothing leaves the device. No telemetry, no accounts, no network access. |
| **📁 Folder = source of truth** | You pick a Vault folder via Android's system picker (SAF). Data survives app uninstall — just reconnect the same folder. |
| **⚡ Fast & lightweight** | OpenCV trimmed to `imgproc` + `imgcodecs` only. Per-ABI splits (~20 MB/APK). Cached thumbnails, downscaled detection (~640 px), full-res warp only on save. |
| **🔄 Non-destructive** | Original captures are **never overwritten**. Every edit is just parameters (crop corners, rotation, filter, sliders) — re-render anytime. |
| **🛡️ Safe by default** | Atomic writes (`temp → fsync → rename`), rebuildable index, every OpenCV `Mat` disposed. No single point of data loss. |
| **👆 Fewest taps** | Camera → Crop → Share PDF. Managing docs is optional. |

---

## Core Features (Phase 1–4 complete)

* **Capture & import** — Live camera preview + batch shutter, or import multiple images from gallery (photo picker).
* **Auto edge detection** — OpenCV contour pipeline (grayscale → Gaussian blur → Canny → largest 4-point contour) runs in a background isolate on a downscaled frame.
* **Manual crop** — 4 draggable corner handles with magnifier loupe; user can always override auto-detection.
* **Perspective correction** — `warpPerspective` flattens/deskews to a clean rectangle at full resolution.
* **Enhance / filters** — Original, **Magic** (CLAHE on L channel), **Grayscale**, **B&W scan** (adaptive threshold), plus **Brightness / Contrast / Sharpness** sliders with live preview.
* **Multi-page documents** — Add, retake, delete, reorder pages (Phase 5).
* **Export & share** — Compile to PDF (A4 / Letter / Auto-fit, quality slider), share via Android share sheet (WhatsApp, Email, Drive, …).

---

## Tech Stack

| Concern | Choice | Why |
|---------|--------|-----|
| Framework | **Flutter 3.38+ / Dart 3.10+** | Required by `dartcv4` native assets |
| SDK isolation | **FVM** | Reproducible builds |
| Camera | `camera` (v0.12+) | Own capture UI + real-time overlay |
| Edge detection / warp / filters | **OpenCV via `dartcv4`** (trimmed to `imgproc` + `imgcodecs`) | Full control, no Play Services; per-ABI splits keep APK small |
| Manual crop UI | Custom Flutter widget | Precise, user-overridable |
| Image utils | `image` (pure Dart) | Encode/rotate fallbacks |
| Folder / SAF | `saf_util` + `saf_stream` | Only actively-maintained SAF combo |
| Prefs (Vault URI token) | `shared_preferences` | Persisted folder URI |
| PDF creation | `pdf` + `printing` | Maintained open-source standard |
| PDF → images (Phase 6) | `pdfrx` (PDFium) | Fast, active wrapper |
| Share | `share_plus` | Android share sheet |
| State management | **Riverpod** | Current best practice |
| OCR (later) | `google_mlkit_text_recognition` | On-device, deferred |

---

## Architecture

```
UI (screens/widgets)
  Onboarding/Connect · Home (docs grid) · Camera+overlay · Crop/Edit · Filter ·
  Document detail (pages) · PDF import/export · Settings
        │
Domain (models + controllers)
  Document · Page · EditParams · VaultConfig · Riverpod controllers
        │
Data (services)
  VaultRepository → SAF file I/O (atomic writes, rebuildable index)
  CvProcessor     → OpenCV in ISOLATE: detect edges, warp, filters; disposes every Mat
  PdfExportService → pages → PDF (pdf + printing)
  PdfImportService → PDF → page images (pdfrx)
  ShareService    → share_plus (regenerates PDF on demand)
  ThumbnailCache  → generate + version + cache thumbnails
```

**CvProcessor rules:** all OpenCV calls run in a background isolate; a `_busy` flag drops overlapping frames; input downscaled to ~640 px for detection; full-res used only for the final warp on save; every `Mat`/detector `.dispose()`d; single-pass pipelines.

---

## The Vault (persistence that survives uninstall)

**Mechanism:** Android Storage Access Framework (SAF). On first run you pick (or create) a folder via the system folder picker. The app takes a **persistable URI permission** to that tree. Files there are **not** app-private, so uninstalling the app does **not** delete them. On reinstall, you re-pick the same folder → the app reads the manifest and restores the whole library.

```
ScanVault/
  version.json                    # schema version + appVersion (for migrations)
  index.json                      # THIN index: [{id, name, date, pageCount, cover}] only
  documents/
    8c2fd123/                     # UUID id (no timestamp-collision risk)
      meta.json                   # authoritative per-doc data (pages, edit params, filter,
                                  #   version, created, updated, appVersion)
      original/page_001.jpg       # untouched capture (non-destructive source)
      processed/page_001.jpg      # cached scanned result (default: cached)
      thumbs/page_001.jpg         # small cached thumbnail (versioned by edit hash)
  exports/                        # transient generated PDFs (regenerable, safe to clear)
  cache/                          # scratch space, safe to delete anytime
```

**Data-safety rules:**
- **Atomic writes:** every `index.json` / `meta.json` write is `temp → fsync → rename`.
- **Rebuildable index:** `index.json` is a cache, not the truth. Missing/corrupt → rescan `documents/` and rebuild from each `meta.json`.
- **Cache processed image by default** (not regenerate-on-open). Store `processed/page.jpg` and keep `original` + params for full re-editability.
- **Thumbnails versioned** by an edit-hash so they invalidate when a page changes.
- **No durable stale PDFs:** exports live in `/exports/` and are regenerated on share.

---

## Build Phases

| Phase | Description | Status |
|-------|------------|--------|
| **0** | Toolchain (Flutter 3.38+, Android SDK, FVM, JDK 17) | ✅ (manual install) |
| **1** | Scaffold + Vault (SAF connect, atomic writes, rebuildable index, home grid) | ✅ |
| **2** | Camera capture + gallery import, save raw pages | ✅ |
| **3** | OpenCV detect & crop (auto edges, manual corners, warp) | ✅ |
| **4** | **Enhance** — OpenCV filters (B&W, Grayscale, Magic, sliders) | ✅ |
| **5** | Multi-page docs, reorder/delete/retake, rename, search | 🔲 |
| **6** | PDF export/import + share, doc→image-folder export | 🔲 |
| **7** | Polish, dark mode, performance, APK-size hardening | 🔲 |
| **8** | Deferred backlog: OCR, undo, camera controls, presets, etc. | 🔲 |

---

## One-Time Environment Setup (Phase 0)

> **You run these once on your machine.**

1. **JDK 17** — Flutter's Android toolchain needs JDK 17 (not 11).
2. **Flutter 3.38+** — add SDK to `PATH`.
3. **Android SDK** — via Android Studio or `cmdline-tools`. Install:
   `platform-tools`, `build-tools;35.0.0`, `platforms;android-35`,
   plus an **x86_64 emulator image** (OpenCV needs `x86_64` native libs for debug).
   Accept licenses: `flutter doctor --android-licenses`.
4. **FVM** (optional but recommended): `dart pub global activate fvm` then `fvm use 3.38.0` (pinned in `.fvmrc`).
5. Set `DARTCV_CACHE_DIR` to a stable path (e.g. `%LOCALAPPDATA%\dartcv-cache`) so the OpenCV SDK downloads once.
6. Verify: `flutter doctor -v` — resolve all ✗.

**Generate the Android platform folder (if missing):**

```bash
git add -A && git commit -m "scaffold before flutter create"
flutter create --org com.scanvault --project-name scanvault --platforms=android .
git checkout -- pubspec.yaml   # keep OUR pubspec (deps + dartcv hooks)
flutter pub get
```

**Android tweaks (applied after `flutter create`):**
- `android/app/build.gradle.kts`: `minSdk = 26`, `targetSdk = 35`, `namespace = "com.scanvault.app"`, `applicationId = "com.scanvault.app"`, release `minifyEnabled true` + `shrinkResources true` + ProGuard rules.
- `kotlin.incremental=false` in `android/gradle.properties` (Windows Defender locks incremental caches).
- Enable native assets: `flutter config --enable-native-assets` (required by `dartcv4` hooks).

---

## Run & Test

```bash
flutter run                      # on emulator (x86_64) or USB device
flutter test                     # pure-Dart unit tests (no device needed)
```

---

## Build (size-conscious — PLAN.md §7)

```bash
flutter build apk --release --split-per-abi \
  --obfuscate --split-debug-info=./debug-info

# Target: < 25 MB per-ABI APK — measure with:
flutter build apk --release --analyze-size --target-platform android-arm64
```

---

## Project Layout

```
lib/
  main.dart                       # entry: load prefs → ProviderScope
  src/
    app/        constants, providers (Riverpod), theme, root gate
    core/       json_utils, failure (typed VaultFailure)
    domain/models/
                Document, DocPage, EditParams, IndexEntry, VaultConfig
    data/vault/  SafGateway (SAF I/O + atomic writes), VaultRepository,
                 VaultPrefs, VaultLayout
    data/cv/     CvProcessor (edge detect, warp, filters, preview — all in isolate)
                 quad_geometry (pure Dart: orderQuad, flattenedSize, plausible checks)
    features/
      onboarding/   ConnectScreen, ReconnectScreen
      home/         HomeScreen (document grid + FAB)
      capture/      CameraCaptureScreen, ImportSource
      crop/         CropReviewScreen (4-corner loupe + rotate)
      enhance/      EnhanceScreen (filter chips + 3 sliders + live preview)
      document/     (Phase 5) detail, reorder, retake
      pdf/          (Phase 6) export, import, share
      settings/     (Phase 7) Vault folder, defaults, theme
test/
  domain_models_test.dart         # JSON round-trips
  quad_geometry_test.dart         # orderQuad, flattenedSize, isPlausibleQuad
  widget_test.dart                # smoke UI test
```

---

## Contributing

This is a personal offline-first scanner. If you want to fork and adapt:

1. Keep it **local-first** — no network dependencies.
2. Keep **OpenCV trimmed** — add modules only if you use them.
3. Every `Mat` **must** be `.dispose()`d — native memory leaks = crashes.
4. Prefer **pure Dart** for geometry / helpers; isolate only heavy OpenCV work.

---

## License

MIT — do whatever you want with it. Attribution appreciated but not required.