git add .
git commit -m "fix: PDF export and sharing bug where pages were ignored due to missing processedPath"
git push

.\.fvm\flutter_sdk\bin\flutter.bat build apk
Copy-Item build\app\outputs\flutter-apk\app-release.apk ScanVault-Universal.apk
.\.fvm\flutter_sdk\bin\flutter.bat build apk --split-per-abi
Copy-Item build\app\outputs\flutter-apk\app-arm64-v8a-release.apk ScanVault-arm64.apk

$uniHash = (Get-FileHash ScanVault-Universal.apk -Algorithm SHA256).Hash.ToLower()
$armHash = (Get-FileHash ScanVault-arm64.apk -Algorithm SHA256).Hash.ToLower()

$notes = "Hotfix for v0.3.0:`n- Fixed a critical bug where Export to PDF would generate blank/loading files.`n- Fixed a bug where sharing individual selected images would fail.`n`n**Hashes:**`nScanVault-arm64.apk`nsha256:$armHash`nScanVault-Universal.apk`nsha256:$uniHash"

gh release create v0.3.1 ScanVault-Universal.apk ScanVault-arm64.apk -t "ScanVault v0.3.1 Hotfix" -n $notes
