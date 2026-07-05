# ScanVault — Document Scanner App (Flutter / Android)

A fast, lightweight, **fully-offline** document scanner (like OKEN Scanner / Microsoft
Lens). Scan or import images → auto-detect document edges (OpenCV) → crop/enhance →
manage multi-page documents → export & share as PDF. **No login, no cloud, no account.**

All data lives in a **user-chosen folder ("Vault")** so it survives app uninstall.
Reinstall the app, reconnect to the same folder, and everything is back.

**Engine decision:** OpenCV (`dartcv4`) — chosen for full control + no Google Play Services
dependency. Kept lightweight via module trimming + ABI splits (see §7). ML Kit is the
documented alternative if we ever want a zero-CV lightweight build.

---

## 1. Product Principles

- **Local-first & private** — nothing leaves the device. No login, no telemetry.
- **Folder = source of truth** — the app is just a viewer/editor over a folder you own.
- **Fast & lightweight** — trim OpenCV to `imgproc`+`imgcodecs`, per-ABI APK split,
  downscale for detection, full-res only on save, cached thumbnails.
- **Non-destructive** — keep the original capture + edit parameters; the "scanned"
  result is regenerable. Never lose the source image.
- **Safe by default** — atomic writes, rebuildable index, no single point of data loss,
  every OpenCV `Mat` disposed.
- **Fewest taps** — the fast path is Camera → Crop → Share PDF. Managing docs is optional.

---

## 2. Core Features

### Capture & Import
- Live camera preview with **real-time edge overlay** (OpenCV contour, drawn on a
  downscaled frame in a background isolate).
- **Auto-capture** (optional, default OFF): shoot when the doc is steady & detected.
- Manual shutter capture.
- **Import from Gallery** / existing images (single or multiple).
- **Import a PDF** → split each PDF page into an image page (see PDF ⇄ Images below).
- Batch mode: capture many pages in a row into one document.

### Detection & Crop (OpenCV / `dartcv4`)
- **Automatic edge detection** — single-pass pipeline: grayscale → Gaussian blur → Canny →
  find largest 4-point contour. Runs on a **downscaled** frame (~640 px) in an **isolate**.
- **Manual crop** — 4 draggable corner handles with a magnifier loupe; the user can always
  override auto-detection.
- **Perspective correction** — `warpPerspective` flattens/deskews to a clean rectangle,
  applied at **full resolution only on final save**.
- Same OpenCV path re-crops gallery imports and imported-PDF pages (one engine everywhere).
- Rotate 90° / auto-orient.

### Enhance / Filters
- Original, **Auto/Magic color**, Grayscale, **B&W scan** (adaptive threshold),
  brightness/contrast/sharpness — all via OpenCV `imgproc` (single-pass where possible).
- Applied per-page, changeable anytime (non-destructive).

### Document Management
- Home screen: **grid/list of documents** with cover thumbnails, name, date, page count.
  *(Mirrors the OKEN home screen: cover thumb + name + date + page-count badge + sort +
  multi-select.)*
- Multi-page documents: **add / retake / delete / reorder** pages (drag to reorder).
  *(Mirrors the OKEN document-detail screen: numbered pages + "add new page" tile.)*
- Rename, duplicate, delete documents.
- Search by name; optional tags/labels.
- Sort by date / name.

### PDF ⇄ Images (both directions)
- **Images → PDF** (scan/export): compile a document's pages into a PDF.
- **PDF → Images (import):** open an existing PDF, **rasterize each page to an image**,
  and turn them into a normal ScanVault document so pages can be re-cropped, re-filtered,
  reordered, or re-exported. *(Rasterizes pages — great for scanned/photo PDFs. It does
  NOT extract editable text; that's OCR, deferred.)*
- **Export document as an image folder:** dump every page as `page_001.jpg …` into a
  chosen folder in the Vault (e.g. `.../MyDoc/images/`).

### Export & Share
- **Export to PDF** — single or multi-page, page size (A4 / Letter / Auto-fit),
  quality/compression setting.
- **Share always regenerates** the PDF from current pages (no stale exports — see §3).
- Export as images (JPG/PNG) too.
- **Share** via Android share sheet (WhatsApp, email, Drive, etc.).

### Settings
- Vault folder location (change / reconnect).
- Default filter, default page size, PDF quality/compression.
- Theme (light / dark / system).
- Auto-capture on/off.

### Later / Optional (Deferred backlog — see §10)
- **OCR** (ML Kit) → searchable PDF + copy text.
- PDF password protection (verify library support first).
- Signature & annotation overlay, QR / barcode scan.
- Undo/redo, Recent/Favorites, camera controls (torch, tap-to-focus, grid), scanner
  presets (ID/receipt/book), batch select, merge, quality warnings (blur/dark/glare).

---

## 3. The Vault (persistence that survives uninstall)

**Mechanism:** Android **Storage Access Framework (SAF)**. On first run the user picks
(or creates) a folder via the system folder picker. The app takes a **persistable URI
permission** to that tree. Files there are **not** app-private, so uninstalling the app
does **not** delete them. On reinstall, the user re-picks the same folder → the app reads
the manifest and restores the whole library.

- Only thing stored in app-private prefs: the folder URI + granted permission token.
  If that's wiped (reinstall / "clear storage"), user just reconnects the folder.
- **Reality check:** persisted-URI survival is reliable on stock Android but flakier on
  some OEMs (Xiaomi/Huawei/some Samsung), and breaks if the folder is on a removed SD
  card or inside a synced Drive/Dropbox folder. So the app must **detect a dead/invalid
  permission and prompt "reconnect your Vault" gracefully** — never crash. Onboarding
  copy is honest ("reconnect the same folder"), not a guarantee.

**Folder layout (UUID ids + per-doc metadata + thin index):**
```
/ScanVault/
  version.json                   # schema version + appVersion (for migrations)
  index.json                     # THIN index: [{id, name, date, pageCount, cover}] only
  /documents/
    /8c2fd123/                   # UUID id (no timestamp-collision risk)
        meta.json                # authoritative per-doc data (pages, edit params, filter,
                                 #   version, created, updated, appVersion)
        /original/page_001.jpg   # untouched capture (non-destructive source)
        /processed/page_001.jpg  # cached scanned result (default: cached, see below)
        /thumbs/page_001.jpg     # small cached thumbnail (versioned by edit hash)
  /exports/                      # transient generated PDFs (regenerable, safe to clear)
  /cache/                        # scratch space, safe to delete anytime
```

**Data-safety rules baked in (Bucket A + B):**
- **Atomic writes:** every `index.json` / `meta.json` write is write-to-temp → fsync →
  rename, so a crash/power-loss never corrupts the index.
- **Rebuildable index:** `index.json` is a cache, not the truth. If it's missing/corrupt,
  or the user adds/deletes a `documents/<id>/` folder in a file manager, the app can
  **rescan `documents/` and rebuild the index** from each `meta.json`.
- **Cache processed image by default** (not regenerate-on-open). Re-running warp+filters
  for every page open is too slow on cheap phones; store `processed/page.jpg` and keep
  `original` + params for full re-editability. "Regenerate on open" is an option.
- **Thumbnails versioned** by an edit-hash so they invalidate when a page changes.
- **No durable stale PDFs:** exports live in `/exports/` and are regenerated on share;
  editing a page never leaves a silently-wrong PDF around.
- **UUID ids** avoid same-second filename collisions; display names stay human ("hostel 4").

---

## 4. Tech Stack

Verified maintained + lightweight as of **July 2026** (see §9 for evidence/sources).

| Concern            | Choice                                                        | Why |
|--------------------|--------------------------------------------------------------|-----|
| Framework          | Flutter (Dart) **3.38+ / Dart 3.10+**                       | required by `dartcv4` hooks/native-assets |
| SDK isolation      | **FVM** (pin Flutter version per project — the "venv" analog) | reproducible builds |
| Camera             | `camera` (live preview + capture)                           | our own capture UI + real-time overlay |
| **Detect / warp / filters** | **OpenCV via `dartcv4`** (`imgproc`+`imgcodecs` only) | full control, no Play Services; trimmed = light |
| Manual crop UI     | custom corner-handle widget (Dart) over the preview         | precise, user-overridable |
| Image utils        | `image` (encode/rotate fallbacks)                           | pure Dart |
| Folder / SAF       | **`saf_util` + `saf_stream`**                                | only *actively-maintained* SAF combo (v3.x, ~1mo ago); older `saf`/`shared_storage` are dead |
| Prefs (URI token)  | `shared_preferences`                                        | store persisted folder URI |
| Images → PDF       | **`pdf` + `printing`**                                       | maintained open-source standard |
| **PDF → images**   | **`pdfrx`** (PDFium, offline)                                | actively developed successor to maintenance-mode `pdf_render` |
| Share              | `share_plus` (or `printing` share)                          | Android share sheet |
| State mgmt         | **`riverpod`** (decided)                                     | current best practice |
| OCR (later)        | `google_mlkit_text_recognition`                             | on-device, deferred |

---

## 5. Architecture

```
UI (screens/widgets)
  Onboarding/Connect · Home (docs grid) · Camera+overlay · Crop/Edit · Filter ·
  Document detail (pages) · PDF import/preview/export · Settings
        │
Domain (models + controllers)
  Document · Page · EditParams · VaultConfig · Riverpod controllers
        │
Data (services)
  VaultRepository  → SAF file IO (saf_util/saf_stream), atomic index/meta writes, rebuild
  CvProcessor      → OpenCV in an ISOLATE: detect edges, warp, filters; disposes every Mat
  PdfExportService → pages → PDF (pdf + printing)
  PdfImportService → PDF → page images (pdfrx)
  ShareService     → share_plus (regenerates PDF on demand)
  ThumbnailCache   → generate + version + cache thumbnails
```

**CvProcessor rules:** all OpenCV calls run in a background isolate; a `_busy` flag drops
overlapping frames; input downscaled to ~640 px for detection; full-res used only for the
final warp on save; every `Mat`/detector `.dispose()`d; single-pass pipelines.

---

## 6. Build Phases (milestones)

- **Phase 0 — Environment** *(later, on your go-ahead)*: install Flutter **3.38+** + Android
  SDK (cmdline-tools, platform-tools, build-tools, platform 34/35), FVM, accept licenses,
  wire a device/emulator, set `DARTCV_CACHE_DIR` so the OpenCV SDK downloads once.
  *Note: no `.venv` — Flutter uses `pubspec.yaml`/FVM.*
- **Phase 1 — Scaffold + Vault**: project setup, folder connect + persistent permission,
  reconnect flow, **atomic writes + rebuildable index**, UUID ids, empty home grid.
- **Phase 2 — Capture/Import**: `camera` capture + gallery import, save raw page to a doc
  (one-page-at-a-time processing).
- **Phase 3 — Detect & Crop (OpenCV)**: `dartcv4` module-trimmed setup, isolate-based
  detection + real-time overlay, manual corner crop, `warpPerspective`; **cache processed
  image**; **verify APK size with `--split-per-abi` early**.
- **Phase 4 — Enhance**: OpenCV filters (B&W threshold, grayscale, auto color, sliders).
- **Phase 5 — Manage**: multi-page docs, reorder/delete/retake, rename, search.
- **Phase 6 — PDF & Share**: PDF export (size/quality), **PDF→images import**,
  **doc→image-folder export**, share regenerates PDF.
- **Phase 7 — Polish**: settings, dark mode, performance, **APK-size hardening** (§7),
  error/reconnect handling.
- **Phase 8 — Deferred backlog**: OCR, undo, camera controls, presets, etc. (see §10).

---

## 7. Keeping OpenCV lightweight & fast (the core concern)

Verified best practices (July 2026) — apply all of these.

### 7a. Shrink the APK
- **Trim modules** in `pubspec.yaml` — the biggest lever. `dartcv4` already defaults to
  `imgproc`+`imgcodecs` and excludes the heavy stuff; make it explicit:
  ```yaml
  hooks:
    user_defines:
      dartcv4:
        include_modules:
          - imgproc      # edges, warp, filters
          - imgcodecs    # jpg/png encode/decode
        exclude_modules:
          - dnn          # deep learning — huge, unused
          - contrib
          - video
          - videoio      # pulls FFMPEG — unused
          - objdetect
          - features2d
          - photo
          - stitching
          - calib3d
          - highgui
  ```
  (`core` is always included and can't be excluded. Excluded modules still expose Dart
  symbols but throw "symbol not found" if called — so just don't call them.)
- **Per-ABI, not a fat APK:**
  - Direct install → `flutter build apk --release --split-per-abi` (or `arm64-v8a` only —
    every modern phone). A fat APK (~45 MB of native libs) → ~20–25 MB per device.
  - Play Store → `flutter build appbundle --release` (Google ships only the matching lib).
- **R8/ProGuard:** `minifyEnabled true` + `shrinkResources true` in release build.
- **Strip native debug symbols** + `--obfuscate --split-debug-info=./debug-info/`
  (keep the debug-info folder for crash de-obfuscation).
- Flutter 3.35+ auto-sets `abiFilters`; if customizing, `abiFilters.clear()` first.
- **Size budget target: < 25 MB per-ABI APK.** Measure with `--analyze-size` each phase.

### 7b. Keep it fast (no UI jank, no OOM)
- **All OpenCV work in a background isolate** — never the main/UI thread.
- **Guard overlapping frames** with a `_busy`/`_detectionInProgress` flag.
- **Downscale before detecting** (cap longest side ~640 px) *inside* the isolate; run
  full-res OpenCV **only** on the final crop/warp at save time.
- **Dispose every `Mat`** — `dartcv4` uses `dart:ffi`; leaked Mats = native OOM crash.
  This is the #1 correctness rule.
- **Single-pass pipeline** (gray → blur → Canny → contour → warp); minimize copies, keep
  Mats native across steps; use async APIs (`cvtColorAsync`, etc.) where helpful.
- Prefer raw camera **YUV/BGRA planes** off the UI thread over `RepaintBoundary→toImage`.
- Use a recent Flutter/Dart SDK (isolate frame-memory leak fixes).

---

## 8. Non-goals (explicit scope boundaries)

- **No cloud sync / multi-device.** The Vault is local; editing the same folder from two
  devices (e.g. via Drive sync) is unsupported and may cause conflicts.
- **No accounts, no ads, no telemetry.**
- **No editable-text extraction** until OCR ships (PDF import rasterizes pages only).
- **Not trying to out-feature CamScanner/Adobe.** The promise is *"the fastest offline
  scanner where your documents stay yours."*

---

## 9. Research findings (verified July 2026)

Why this stack is the current best "maintained + lightweight + safe" choice:

- **OpenCV (`opencv_dart`/`dartcv4`)**: actively maintained (Feb 2026). Heavy *by default*
  (~100 MB build SDK) but the **APK stays light** via module trimming (`imgproc`+`imgcodecs`)
  + ABI splits (§7). Needs Flutter 3.38+/Dart 3.10+. No Google Play Services dependency,
  full control — chosen as the engine.
- **ML Kit Document Scanner** (`google_mlkit_document_scanner`): tiny (models via Play
  Services), Google-maintained, but needs Play Services + Android-only + Beta + fixed UI.
  Kept as the documented lightweight alternative (backlog).
- **SAF plugins**: `saf` is **broken** on modern Flutter and `shared_storage` is
  **discontinued** — do NOT use them. **`saf_util` (v3.1.0, ~1 month old) + `saf_stream`**
  is the maintained pairing for pick-folder + persisted permission + read/write.
- **PDF → images**: `pdf_render` is **maintenance-mode**; its author endorses **`pdfrx`**
  (PDFium, fast, active). Native Android `PdfRenderer` is lightest but lacks a maintained
  wrapper → **`pdfrx`** picked for safety.
- **PDF creation**: `pdf` + `printing` (DavBfr) remain the maintained open-source standard.
- **State management**: Riverpod confirmed as current best practice.
- **Huawei HMS / Scanbot / Dynamsoft / Docutain**: rejected — Huawei plugin is stale &
  Huawei-only; the self-contained engines are all paid (against the free/local goal).

Sources: [Flutter Gems — Document Scanner](https://fluttergems.dev/document-scanner/) ·
[opencv_dart](https://pub.dev/packages/opencv_dart) · [dartcv4](https://pub.dev/packages/dartcv4) ·
[opencv_dart changelog](https://pub.dev/packages/opencv_dart/changelog) ·
[Flutter --split-per-abi](https://docs.flutter.dev/release/breaking-changes/default-abi-filters-android) ·
[Real-time edge detection w/ opencv_dart](https://medium.com/@kishansakariya0000/real-time-edge-detection-in-flutter-using-opencv-opencv-dart-full-guide-working-code-fe6946d6799e) ·
[saf_util](https://pub.dev/packages/saf_util) · [pdfrx](https://pub.dev/packages/pdfrx) ·
[pdf](https://pub.dev/packages/pdf) · [printing](https://pub.dev/packages/printing)

---

## 10. Deferred backlog (do NOT build for v1 — parked on purpose)

Captured so good ideas aren't lost, but explicitly out of the v1 build to avoid scope creep:
- OCR (searchable PDF, copy text, in-document search), PDF password (AES) — verify libs.
- Undo/redo, Recent/Favorites, autosave drafts, retake history per page.
- Camera controls: torch, tap-to-focus, exposure lock, grid, level, stability indicator.
- Quality warnings (blur/dark/glare/cut-edge), scanner presets (ID/receipt/book/whiteboard).
- Batch operations (multi-select delete/share/merge), merge docs, split.
- Move index from `index.json` → SQLite/Isar **only if** libraries grow past ~1–2k docs
  (files unchanged; swap the index layer).
- Background/cancelable export with progress notification for very large PDFs.
- Recycle bin / local backups, optional encrypted Vault, accessibility (TalkBack), i18n/RTL.
- **ML Kit engine build** — a lightweight Play-Services-based alternative to OpenCV, if we
  ever want a zero-CV, even-smaller build.

---

## 11. Open Questions (before Phase 0)

1. **Minimum Android version?** (e.g. Android 8 / API 26 — affects SAF & `camera` plugin.)
2. **Default Vault location?** Recommend defaulting to `Documents/ScanVault` (still
   redirectable via SAF) to reduce first-run friction.
3. **App name / package id?** (e.g. `com.yourname.scanvault`.)
4. **Target device** for testing: physical phone (USB debugging) or emulator?
   *(Note: OpenCV needs `x86_64` native libs for emulators — include that ABI in debug.)*
</content>
</invoke>
