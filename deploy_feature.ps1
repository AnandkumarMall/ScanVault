git add .
git commit -m "feat: add post-save image cropping and editing using image_cropper"
git push

.\.fvm\flutter_sdk\bin\flutter.bat build apk
Copy-Item build\app\outputs\flutter-apk\app-release.apk ScanVault-Universal.apk
.\.fvm\flutter_sdk\bin\flutter.bat build apk --split-per-abi
Copy-Item build\app\outputs\flutter-apk\app-arm64-v8a-release.apk ScanVault-arm64.apk

$uniHash = (Get-FileHash ScanVault-Universal.apk -Algorithm SHA256).Hash.ToLower()
$armHash = (Get-FileHash ScanVault-arm64.apk -Algorithm SHA256).Hash.ToLower()

$notes = "New Feature:`n- Added a fully functional Post-Save Editor! You can now tap **Edit / Crop** on any saved document to precisely adjust its borders, crop, or rotate the image without losing quality.`n`n**Hashes:**`nScanVault-arm64.apk`nsha256:$armHash`nScanVault-Universal.apk`nsha256:$uniHash"

gh release create v0.4.0 ScanVault-Universal.apk ScanVault-arm64.apk -t "ScanVault v0.4.0: The Editor Update" -n $notes
