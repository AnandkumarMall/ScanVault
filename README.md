# ScanVault

**A fast, lightweight, fully-offline document scanner for Android.**

> No login. No cloud. No account. Your documents never leave your device.

ScanVault is a privacy-first document scanning application. Capture documents with your camera, automatically detect edges, apply enhancements, and manage your files—all entirely on-device without any network calls or telemetry.

---

## 🌟 Key Features

### 🛡️ Privacy & Security First
* **100% Offline:** Nothing leaves your device. No telemetry, no tracking, and no accounts required.
* **App PIN Lock:** Secure your scanned documents with an optional 4-digit passcode lock built right into the app.
* **Vault Storage:** Uses Android's Storage Access Framework (SAF) to create a "Vault" folder on your device. Your data survives app uninstalls—simply reconnect the same folder upon reinstall to restore everything!

### 📸 Smart Scanning & Cropping
* **Auto Edge Detection:** Powered by an optimized OpenCV contour pipeline that runs smoothly in a background thread.
* **Precision Manual Crop:** Fine-tune your document borders with 4 draggable corner handles and a built-in magnifier loupe for pixel-perfect accuracy.
* **Perspective Correction:** Warps and flattens your skewed scans into perfectly straight, full-resolution rectangles.
* **Import from Anywhere:** Live camera preview with batch capturing, or seamlessly import existing images and PDFs from your device.

### 🎨 Powerful Image Enhancements
* **Advanced Filters:** Choose between Original, **Magic** (CLAHE enhancement), **Grayscale**, and **B&W Scan** (adaptive thresholding).
* **Granular Controls:** Manually adjust Brightness, Contrast, and Sharpness with real-time live previews.
* **Non-Destructive Editing:** Your original captures are never overwritten. Every edit is saved as parameters, meaning you can endlessly re-edit or revert your scans at any time.

### 📑 Document Management & Export
* **Intuitive Organization:** A stunning, glassmorphism-inspired UI with smooth animations.
* **Full Control:** Add, retake, delete, and drag-and-drop pages to effortlessly reorder them. 
* **Merge Documents:** Select multiple separate documents and instantly merge them into one unified file.
* **Export & Share:** Compile your scans into a PDF (with A4 / Letter / Auto-fit options and quality sliders) or share them directly as high-quality JPEG images via the Android share sheet.

---

## 🛠️ Technical Architecture

ScanVault is built for extreme performance and absolute data safety.

| Concern | Choice | Why |
|---------|--------|-----|
| **Framework** | Flutter 3.38+ / Dart 3.10+ | Fluid UI with cross-platform native compilation. |
| **State Management** | Riverpod | Predictable, safe, and modern state management. |
| **Edge Detection & Filters**| OpenCV (`dartcv4`) | Native C++ processing trimmed to just `imgproc` and `imgcodecs` for tiny APK sizes (~50MB). |
| **Storage & I/O** | `saf_util` | Direct, persistent, and permission-granted Android SAF interactions. |
| **PDF Handling** | `pdf` & `printing` | Fast and customizable on-device PDF generation. |

### Data Safety Guarantee
- **Atomic Writes:** Every database change uses a safe `temp → fsync → rename` strategy.
- **Rebuildable Index:** The app's cache (`index.json`) can be corrupted or deleted, and the app will flawlessly rebuild it by scanning your Vault's `meta.json` files.
- **Memory Optimized:** OpenCV `Mat` objects are meticulously disposed of, and UI thumbnails are aggressively downscaled and cached to prevent RAM bloat and ensure buttery-smooth scrolling. All heavy processing is offloaded to a background Dart Isolate.

---

## 🚀 Building & Running Locally

### 1. Prerequisites
* **JDK 17** (Required by Flutter's Android toolchain).
* **Flutter 3.38+** (Added to your system `PATH`).
* **Android SDK** (Install `platform-tools`, `build-tools;35.0.0`, `platforms;android-35`).

### 2. Setup
Clone the repository and ensure your environment supports Flutter's new native assets feature:
```bash
flutter config --enable-native-assets
flutter pub get
```

### 3. Run
```bash
flutter run
```

### 4. Build Optimized Release APK
To build a highly optimized, lightweight APK for a modern Android device (stripping out unused CPU architectures):
```bash
flutter build apk --release --split-per-abi --obfuscate --split-debug-info=./debug-info
```
Your optimized APKs will be located in `build/app/outputs/flutter-apk/`.

---

## 🤝 Contributing
This is an open-source, offline-first scanner. If you want to fork and adapt:
1. **Keep it local-first** — no network dependencies or cloud APIs.
2. **Keep OpenCV trimmed** — add modules in `pubspec.yaml` only if you explicitly use them to keep the app lightweight.
3. **Memory Management** — Every OpenCV `Mat` **must** be `.dispose()`d to prevent native memory leaks.

## 📄 License
MIT License. Do whatever you want with it! Attribution is appreciated but not required.