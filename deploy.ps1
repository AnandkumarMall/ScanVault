.\.fvm\flutter_sdk\bin\flutter.bat build apk
Copy-Item build\app\outputs\flutter-apk\app-release.apk ScanVault-Universal.apk
.\.fvm\flutter_sdk\bin\flutter.bat build apk --split-per-abi
Copy-Item build\app\outputs\flutter-apk\app-arm64-v8a-release.apk ScanVault-arm64.apk

$uniHash = (Get-FileHash ScanVault-Universal.apk -Algorithm SHA256).Hash.ToLower()
$armHash = (Get-FileHash ScanVault-arm64.apk -Algorithm SHA256).Hash.ToLower()

$notes = "Includes Google ML Kit document scanner integration, dynamic Light/Dark mode, zoom improvements, and extensive performance optimizations by stripping FFI overhead.`n`n**Assets**`nScanVault-arm64.apk`nsha256:$armHash`nScanVault-Universal.apk`nsha256:$uniHash"

gh release create v0.3.0 ScanVault-Universal.apk ScanVault-arm64.apk -t "ScanVault v0.3.0" -n $notes
