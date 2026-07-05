# ScanVault ProGuard/R8 rules (release build, PLAN.md §7a).
# Flutter's embedding + plugins are largely covered by their own consumer rules;
# add app-specific keeps here as needed.

# Keep Flutter embedding (defensive; usually covered by the engine's rules).
-keep class io.flutter.embedding.** { *; }
-dontwarn io.flutter.embedding.**

# dartcv4/OpenCV run through dart:ffi against bundled .so files — no Java/Kotlin
# reflection to preserve. Nothing extra required here today; keep this note so
# future native plugins that DO use reflection get their -keep rules added.
