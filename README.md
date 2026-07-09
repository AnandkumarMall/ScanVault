# ScanVault

**A fast, beautifully designed, fully-offline document scanner for Android.**

> No login. No cloud. No account. Your documents never leave your device.

ScanVault is a privacy-first document scanning application. Capture documents with your camera using advanced ML-based edge detection, securely manage your files with PIN protection, and enjoy a meticulously handcrafted UI—all entirely on-device without any network calls or telemetry.

---

## 🌟 Key Features

### 🛡️ Privacy & Security First
* **100% Offline:** Nothing leaves your device. No telemetry, no tracking, and no accounts required.
* **App PIN Lock:** Secure your scanned documents with an optional 4-digit passcode lock built right into the app.
* **Vault Storage:** Uses Android's Storage Access Framework (SAF) to create a "Vault" folder on your device. Your data survives app uninstalls—simply reconnect the same folder upon reinstall to restore everything!

### 📸 Smart Scanning & ML Integration
* **ML Kit Powered Scanning:** Utilizes native ML Kit (via `cunning_document_scanner`) for buttery smooth, highly accurate document edge detection and perspective correction.
* **Batch Import:** Quickly scan multiple pages in a row or import existing photos from your gallery.

### 🎨 Stunning Minimalist Design
* **Custom Design System:** Built from the ground up with a warm, minimalist aesthetic featuring glassmorphism overlays and dynamic glow effects.
* **Dynamic Dark/Light Mode:** First-class support for both Light and Dark themes, seamlessly integrated throughout the app.
* **Abstract App Icon:** A beautiful, custom vector-designed app icon that perfectly matches the app's clean aesthetic.

### 📑 Document Management & Export
* **Intuitive Organization:** Effortlessly add, delete, and reorder pages within your documents.
* **Merge Documents:** Select multiple separate documents and instantly merge them into one unified file.
* **Export & Share:** Compile your scans into a PDF or share them directly as high-quality JPEG images via the Android share sheet.

---

## 🛠️ Technical Architecture

ScanVault is built for extreme performance, absolute data safety, and a premium look and feel.

| Concern | Choice | Why |
|---------|--------|-----|
| **Framework** | Flutter / Dart | Fluid UI with cross-platform native compilation. |
| **State Management** | Riverpod | Predictable, safe, and modern state management. |
| **Scanning Engine** | ML Kit (`cunning_document_scanner`) | High-performance, native edge detection and cropping without the overhead of heavy FFI bindings. |
| **Storage & I/O** | `saf_util` | Direct, persistent, and permission-granted Android SAF interactions. |
| **PDF Handling** | `pdf` & `printing` | Fast and customizable on-device PDF generation. |

### Data Safety Guarantee
- **Atomic Writes:** Every database change uses a safe `temp → fsync → rename` strategy.
- **Rebuildable Index:** The app's cache (`index.json`) can be corrupted or deleted, and the app will flawlessly rebuild it by scanning your Vault's `meta.json` files.
- **Performance Optimized:** Heavy image processing tasks (like generating PDF exports or rendering edits) are offloaded to background Isolates to ensure the main UI thread remains completely fluid.

---

## 🚀 Building & Running Locally

### 1. Prerequisites
* **JDK 17** (Required by Flutter's Android toolchain).
* **Flutter SDK** (Recommended to use FVM, or have Flutter installed in your `PATH`).
* **Android SDK** (Install `platform-tools`, `build-tools`, and relevant Android platforms).

### 2. Setup & Run
Clone the repository, fetch dependencies, and run:
```bash
flutter pub get
flutter run
```

### 3. Build Optimized Release APK
To build a highly optimized, lightweight APK for a modern Android device:
```bash
flutter build apk --release
```
Your optimized APK will be located in `build/app/outputs/flutter-apk/app-release.apk`.

---

## 📄 License
MIT License. Do whatever you want with it! Attribution is appreciated but not required.