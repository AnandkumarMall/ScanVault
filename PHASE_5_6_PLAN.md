# ScanVault — Phase 5 (Manage) & Phase 6 (PDF & Share) Implementation Plan

---

## Current State Summary (Phases 1–4 Complete)

| Phase | Status | Key Deliverables |
|-------|--------|------------------|
| **1** | ✅ Done | Vault connect/reconnect, atomic writes, rebuildable index, UUID ids, empty home grid |
| **2** | ✅ Done | Camera capture (batch mode), gallery import, raw page save |
| **3** | ✅ Done | `dartcv4` trimmed setup, isolate detection, real-time overlay, manual crop, `warpPerspective`, cached processed images |
| **4** | ✅ Done | OpenCV filters (original/autoColor/grayscale/B&W), brightness/contrast/sharpness sliders, live preview in `EnhanceScreen` |

**Flow so far:** `HomeScreen` → (camera/gallery) → `CropReviewScreen` → `EnhanceScreen` → save document.

---

## Phase 5 — Document Management (Multi-page, Reorder, Delete, Retake, Rename, Search)

**Goal:** Make documents fully editable after creation. Mirrors OKEN's document-detail screen.

### 5.1 Document Detail Screen (`DocumentDetailScreen`)

**File:** `lib/src/features/document/document_detail_screen.dart`

**Features:**
- Grid/list of pages (numbered thumbnails, full-width cards)
- **"Add page" tile** — opens capture/import → crop → enhance → appends page
- Tap page → **Page Review Screen** (crop/enhance existing page with current params pre-filled)
- Long-press page → **multi-select mode** (checkboxes) → delete selected
- **Reorder** — drag handles (ReorderableGridView) to reorder pages; persists on drop
- **"Retake"** — replaces a specific page: capture new image → crop → enhance → replace
- **Rename document** — from app bar action or long-press on home grid

**Navigation:**
- `HomeScreen` tap card → `DocumentDetailScreen`
- `DocumentDetailScreen` "Add page" → `CameraCaptureScreen` / gallery → `CropReviewScreen` → `EnhanceScreen` → returns new page
- `DocumentDetailScreen` tap page → `PageReviewScreen` (pre-filled params) → `CropReviewScreen` → `EnhanceScreen` → returns updated page

### 5.2 Page Review Screen (`PageReviewScreen`)

**File:** `lib/src/features/document/page_review_screen.dart`

- Similar to `CropReviewScreen` but for **single page with existing `EditParams` pre-loaded**
- Shows current crop + filter + sliders
- User can re-crop, change filter, adjust sliders
- Returns updated `EditParams`

### 5.3 VaultRepository Extensions

**File:** `lib/src/data/vault/vault_repository.dart` (add methods)

```dart
// Replace a single page (retake)
Future<Document> replacePage(String docId, int pageIndex, Uint8List newOriginal, EditParams newEdit);

// Reorder pages
Future<Document> reorderPages(String docId, int oldIndex, int newIndex);

// Delete specific pages by index
Future<Document> deletePages(String docId, List<int> pageIndices);

// Update a page's edit params (after re-crop/enhance of existing page)
Future<Document> updatePageEdit(String docId, int pageIndex, EditParams edit);
```

**Implementation notes:**
- `replacePage`: write new `original/`, `processed/`, `thumb/` files; update `DocPage` in `pages` list; `saveDocument()`
- `reorderPages`: `List.move()` on `doc.pages`; `saveDocument()`
- `deletePages`: remove `DocPage` entries; delete associated files from SAF; `saveDocument()`
- `updatePageEdit`: regenerate `processed/` + `thumb/` from `original/` + new `EditParams`; update `DocPage`; `saveDocument()`

### 5.4 HomeScreen Enhancements

**File:** `lib/src/features/home/home_screen.dart`

- **Tap card** → navigate to `DocumentDetailScreen`
- **Long-press card** → bottom sheet: Rename / Delete (already has Delete)
- **Search** — `TextField` in app bar (or search action) → filter `IndexEntry` list locally (fast, client-side)
- **Sort** — dropdown: Date (newest/oldest) / Name (A-Z/Z-A) — persists in prefs
- **Multi-select mode** on home grid (long-press) → bulk delete / share

### 5.5 Providers

**File:** `lib/src/app/providers.dart` (add)

```dart
// Document detail controller (manages one document's loaded state)
final documentDetailProvider = AsyncNotifierProvider.autoDispose
    .family<DocumentDetailController, Document, String>(...);

// Search/filter/sort state for home
final homeSearchProvider = StateProvider<String>((ref) => '');
final homeSortProvider = StateProvider<HomeSort>((ref) => HomeSort.dateDesc);
```

### 5.6 Models (if needed)

Check `DocPage` has everything — it does (`id`, `originalPath`, `processedPath`, `thumbPath`, `edit`).

---

## Phase 6 — PDF Export, PDF Import (rasterize), Image-Folder Export, Share

**Goal:** Full round-trip: images → PDF, PDF → images (as editable document), document → image folder, share via Android sheet.

### 6.1 Dependencies (add to `pubspec.yaml`)

```yaml
dependencies:
  # PDF → images import (PDFium, offline)
  pdfrx: ^1.0.90

  # Already present:
  # pdf: ^3.11.1
  # printing: ^5.13.4
  # share_plus: ^13.2.0
```

**Note:** `pdfrx` on Windows requires Developer Mode (symlinks). Document this in README.

### 6.2 PDF Export Service

**File:** `lib/src/data/pdf/pdf_export_service.dart`

```dart
class PdfExportService {
  const PdfExportService();

  /// Builds a PDF from a document's processed pages.
  /// [pageSize] = A4 / Letter / Auto-fit (fit to image aspect).
  /// [quality] = JPEG compression for embedded images (1–100).
  Future<Uint8List> exportPdf({
    required Document document,
    required VaultRepository vault, // to read page bytes
    required PdfPageSize pageSize,
    required int quality,
  });
}
```

**Implementation:**
- Use `package:pdf` + `package:printing` (or just `pdf` for bytes)
- Iterate `document.pages` in order
- For each page: read `processedPath` (or `originalPath` fallback) via `vault.readDocumentFile()`
- Add page to PDF with proper sizing:
  - **A4 / Letter**: fit image into page bounds, center, maintain aspect
  - **Auto-fit**: page size = image size (point-for-point, or configurable DPI)
- Return `Uint8List` PDF bytes

### 6.3 PDF Import Service (Rasterize)

**File:** `lib/src/data/pdf/pdf_import_service.dart`

```dart
class PdfImportService {
  const PdfImportService();

  /// Rasterizes each PDF page to an image (DPI configurable, default 200).
  /// Returns list of (pageIndex, imageBytes) for the Crop/Enhance flow.
  Future<List<Uint8List>> rasterizePdf({
    required String pdfUri, // SAF URI
    int dpi = 200,
  });
}
```

**Implementation:**
- Use `pdfrx` (PDFium) — open PDF from SAF `InputStream` (`saf_stream`)
- For each page: `page.render(dpi * 72 / 72)` → get bitmap → encode to JPEG
- Return list of JPEG bytes
- **Flow in HomeScreen:** "Import PDF" → pick file via SAF → `PdfImportService.rasterizePdf()` → `CropReviewScreen` (one entry per page) → `EnhanceScreen` → save → save as normal document

### 6.4 Document → Image Folder Export

**File:** `lib/src/data/vault/vault_repository.dart` (add method)

```dart
/// Exports all pages of a document as individual image files into a
/// chosen folder inside the Vault (e.g. `exports/MyDoc/images/`).
/// Returns the folder URI.
Future<String> exportDocumentAsImages({
  required String docId,
  required String targetFolderName, // user picks or we suggest
  required bool useProcessed, // true = processed (cropped/enhanced), false = original
});
```

**Implementation:**
- Create `exports/<docName>/images/` under Vault root (or user-picked folder via SAF)
- For each page: read `processedPath` or `originalPath` → write as `page_001.jpg`, `page_002.jpg`...
- Return folder URI for sharing

### 6.5 Share Service

**File:** `lib/src/services/share_service.dart`

```dart
class ShareService {
  const ShareService();

  /// Regenerates PDF from current document state and shares via Android share sheet.
  Future<void> shareDocumentAsPdf({
    required Document document,
    required VaultRepository vault,
    required PdfExportService pdfExport,
    required String subject,
  });

  /// Shares exported image folder.
  Future<void> shareDocumentAsImages({
    required String folderUri, // from exportDocumentAsImages
    required String subject,
  });
}
```

**Key principle:** **Share always regenerates** — no stale PDFs (PLAN.md §3).

### 6.6 DocumentDetailScreen — Export/Share Actions

Add to app bar / overflow menu:
- **Export / Share as PDF** → opens bottom sheet: choose page size (A4/Letter/Auto) + quality → generates PDF → share sheet
- **Export as Images** → exports to `exports/<name>/images/` → share folder or "Save to Files"
- **Import PDF** (from home FAB or document detail) → SAF file picker → `PdfImportService` → crop/enhance flow

### 6.7 HomeScreen — Import PDF

Add to FAB bottom sheet: **"Import PDF"** → SAF picker (`saf_util.pickFile()` with `application/pdf`) → rasterize → crop/enhance per page.

---

## Technical Details & Edge Cases

### SAF File Picking for PDF Import
```dart
// In SafGateway
Future<SafFile?> pickPdfFile() async {
  final intent = Intent(Intent.ACTION_OPEN_DOCUMENT)
      .setType('application/pdf')
      .putExtra(Intent.EXTRA_ALLOW_MULTIPLE, false);
  return _pickSingle(intent); // similar to pickVaultDirectory but for files
}
```

### PDF Rendering (pdfrx)
```dart
final document = await PdfDocument.openStream(SafInputStream(uri));
for (int i = 1; i <= document.pagesCount; i++) {
  final page = await document.getPage(i);
  final bitmap = await page.render(width: page.width * dpi / 72, height: page.height * dpi / 72);
  final jpeg = await bitmap.toJpeg(quality: 90);
  pages.add(jpeg);
}
await document.close();
```

### PDF Page Sizing (Auto-fit)
- A4: 595 × 842 pt (72 DPI)
- Letter: 612 × 792 pt
- **Auto-fit**: Create PDF page with image's pixel dimensions at 72 DPI (or 300 DPI for print quality)
- Use `pdf` package: `pw.MemoryImage(bytes)` → `pw.Image` with `fit: pw.BoxFit.contain`

### Reorder Persistence
- `ReorderableGridView` on drag end → call `repo.reorderPages(docId, oldIndex, newIndex)`
- `doc.pages` is a `List<DocPage>` — `List.insert()` + `List.removeAt()` → `saveDocument()`

### Thumbnail Invalidation
- When a page is replaced/updated: `edited.editHash()` changes → new thumb filename
- Thumb path includes hash or just overwrite `thumb/<pageId>.jpg` (versioned by `updatedAt` in index key)

---

## File Map (New / Modified)

### Phase 5 — Manage
| File | Type | Description |
|------|------|-------------|
| `lib/src/features/document/document_detail_screen.dart` | **NEW** | Main document detail: page grid, add/retake/reorder/delete |
| `lib/src/features/document/page_review_screen.dart` | **NEW** | Re-crop/enhance existing page with pre-filled params |
| `lib/src/features/document/document_detail_controller.dart` | **NEW** | Riverpod controller for document detail state |
| `lib/src/data/vault/vault_repository.dart` | **MODIFY** | Add `replacePage`, `reorderPages`, `deletePages`, `updatePageEdit` |
| `lib/src/app/providers.dart` | **MODIFY** | Add `documentDetailProvider`, `homeSearchProvider`, `homeSortProvider` |
| `lib/src/features/home/home_screen.dart` | **MODIFY** | Tap→detail, search, sort, multi-select bulk actions |

### Phase 6 — PDF & Share
| File | Type | Description |
|------|------|-------------|
| `lib/src/data/pdf/pdf_export_service.dart` | **NEW** | Images → PDF (A4/Letter/Auto, quality) |
| `lib/src/data/pdf/pdf_import_service.dart` | **NEW** | PDF → images (pdfrx rasterize) |
| `lib/src/services/share_service.dart` | **NEW** | Share PDF (regenerates) / share image folder |
| `lib/src/data/vault/vault_repository.dart` | **MODIFY** | Add `exportDocumentAsImages` |
| `lib/src/data/vault/saf_gateway.dart` | **MODIFY** | Add `pickPdfFile()` for PDF import |
| `lib/src/app/providers.dart` | **MODIFY** | Add `pdfExportProvider`, `pdfImportProvider`, `shareProvider` |
| `lib/src/features/home/home_screen.dart` | **MODIFY** | FAB: add "Import PDF" |
| `lib/src/features/document/document_detail_screen.dart` | **MODIFY** | Add export/share actions |
| `pubspec.yaml` | **MODIFY** | Add `pdfrx: ^1.0.90` |

---

## Implementation Order (Suggested)

### Phase 5
1. **VaultRepository extensions** — core data mutations (replace, reorder, delete pages, update edit)
2. **DocumentDetailScreen** — page grid + "Add page" tile (hooks into existing capture→crop→enhance flow)
3. **PageReviewScreen** — re-edit existing page
4. **Hook up navigation** from HomeScreen tap
4. **Home enhancements** — search, sort, rename, multi-select bulk delete

### Phase 6
1. **Add `pdfrx`** to pubspec (enable Developer Mode on Windows for symlinks)
2. **PdfExportService** — test with a document
3. **PdfImportService** — test PDF → images → crop/enhance → save
4. **ShareService** — share generated PDF + image folder
5. **VaultRepository.exportDocumentAsImages**
6. **SAF Gateway: pickPdfFile**
7. **UI integration** — home FAB "Import PDF", document detail export/share menu

---

## Testing Checklist

### Phase 5
- [ ] Create document → open detail → add 3 pages (camera + gallery) → verify grid
- [ ] Reorder pages via drag → close & reopen → order persisted
- [ ] Retake page 2 → verify new image replaces old, thumbnail updates
- [ ] Delete page 1 → verify remaining pages re-indexed
- [ ] Re-crop/enhance page via tap → verify processed + thumb regenerated
- [ ] Rename document from home long-press → index updates
- [ ] Search filters grid in real-time
- [ ] Sort toggles persist across app restarts
- [ ] Multi-select delete on home grid

### Phase 6
- [ ] Export document as PDF (A4, Letter, Auto) → open PDF → pages correct
- [ ] Share PDF → WhatsApp/Email/GDrive receives valid PDF
- [ ] Import multi-page PDF → each page goes through crop/enhance → saved as document
- [ ] Export document as image folder → `page_001.jpg`... in folder → share folder
- [ ] Edit a page after PDF export → share again → PDF reflects edits (regenerated)
- [ ] APK size with `--split-per-abi` < 25 MB per ABI (run `flutter build apk --release --split-per-abi --analyze-size`)

---

## Open Questions / Decisions Needed

1. **PDF page size default**: Auto-fit or A4? (OKEN uses A4 default)
2. **PDF quality default**: 90? (Matches processed JPEG quality)
3. **Import PDF DPI**: 200 DPI default? (Balances quality/size; 300 for OCR later)
4. **Image folder export location**: Always `exports/<docName>/images/` or let user pick via SAF?
5. **Search scope**: Client-side filter on `IndexEntry` name only? (Server-side not needed for local vault)
6. **Multi-select UX**: Long-press on home grid + checkboxes, or "Select" mode button in app bar?

---

## Rollback / Risk Mitigation

- **VaultRepository**: Each new method follows existing atomic pattern — `saveDocument()` invalidates index
- **PDF services**: Pure Dart + isolates where needed; failures fall back gracefully (share original images)
- **pdfrx**: If CMake/symlink issues block Windows dev, defer PDF import to device testing only
- **Reorder**: Use `ReorderableGridView` (Flutter built-in) — no external drag-drop lib

---

## Estimated Effort

| Phase | Files | Complexity | Est. Days |
|-------|-------|------------|-----------|
| 5.1–5.4 (Core manage) | 6 new + 3 mod | Medium | 3–4 |
| 5.5–5.6 (Home polish) | 2 mod | Low | 1 |
| 6.1–6.3 (PDF export/import) | 3 new + 1 mod | Medium | 2–3 |
| 6.4–6.7 (Share + UI) | 2 new + 4 mod | Medium | 2 |
| **Total** | **~11 new, ~8 mod** | | **8–10 days** |

---

## Next Steps

1. Confirm this plan aligns with your priorities
2. Start with **Phase 5.1** (`VaultRepository` extensions) — unlocks all downstream UI
3. Set up `pdfrx` in a test branch to verify Windows build (Developer Mode + symlinks)
4. Begin implementation