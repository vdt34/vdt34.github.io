$ErrorActionPreference = "Stop"

Write-Host "=== 1) Compile Java -> smali_classes3 ==="
& powershell -NoProfile -ExecutionPolicy Bypass -File "C:\Users\VDT\.gemini\antigravity\scratch\voice_portal_src\build_smali.ps1"
if ($LASTEXITCODE -ne 0) { throw "build_smali failed" }

$outDir = "C:\Users\VDT\.gemini\antigravity\scratch\dist_art"
$unsigned = "$outDir\R1_1.1.6_4mic_unsigned.apk"
$signed = "$outDir\R1_1.1.6_4mic_unsigned-aligned-debugSigned.apk"
Remove-Item $unsigned, $signed -Force -ErrorAction SilentlyContinue

Write-Host "`n=== 2) apktool build ==="
& java -jar "C:\Users\VDT\.gemini\antigravity\scratch\tools\apktool.jar" b "C:\Users\VDT\.gemini\antigravity\scratch\apk_patch_mic" -o $unsigned
if ($LASTEXITCODE -ne 0) { throw "apktool b failed" }

Write-Host "`n=== 3) uber-apk-signer ==="
& java -jar "C:\Users\VDT\.gemini\antigravity\scratch\tools\uber-apk-signer.jar" --apks $unsigned --out $outDir
if ($LASTEXITCODE -ne 0) { throw "uber-apk-signer failed" }

Write-Host "`n=== 4) Deploy & verify BOTH speakers (192.168.50.48 & 192.168.50.37) ==="
& python "C:\Users\VDT\.gemini\antigravity\brain\6fc6c5fd-ec7e-49ae-9257-2cb58773df6b\scratch\deploy_both_speakers.py"
if ($LASTEXITCODE -ne 0) { throw "deploy_both_speakers failed" }
