<#
  Cari Takip - Windows sürüm derleme betiği.

  Kullanım (PowerShell, proje kökünde veya herhangi bir yerde):
      .\installer\build_windows.ps1
      .\installer\build_windows.ps1 -SkipTests     # testleri atla (önerilmez)

  Yaptığı işler: pubspec'ten sürümü okur -> analyze + test -> release build ->
  MSVC çalışma zamanı DLL'lerini ekler -> Inno Setup ile kurulum dosyası üretir.
  Çıktı: installer\Output\CariTakip_Kurulum_<sürüm>.exe
#>
param([switch]$SkipTests)

$ErrorActionPreference = 'Stop'
Set-Location (Split-Path $PSScriptRoot -Parent)   # proje kökü

function Fail($message) { Write-Host "HATA: $message" -ForegroundColor Red; exit 1 }
function Step($message) { Write-Host "`n==> $message" -ForegroundColor Cyan }

# 1) Sürüm (pubspec.yaml: version: 1.0.0+1  ->  1.0.0)
$match = Select-String -Path pubspec.yaml -Pattern '^version:\s*(\S+)' | Select-Object -First 1
if (-not $match) { Fail 'pubspec.yaml içinde version bulunamadı.' }
$version = $match.Matches[0].Groups[1].Value.Split('+')[0]
Write-Host "Sürüm: $version"

# 2) Bağımlılıklar, analiz, testler
Step 'flutter pub get'
flutter pub get
if ($LASTEXITCODE -ne 0) { Fail 'flutter pub get başarısız.' }

if (-not $SkipTests) {
  Step 'flutter analyze'
  flutter analyze
  if ($LASTEXITCODE -ne 0) { Fail 'flutter analyze hata verdi; sürüm üretilmedi.' }

  Step 'flutter test'
  flutter test
  if ($LASTEXITCODE -ne 0) { Fail 'Testler başarısız; sürüm üretilmedi.' }
}

# 3) Release build
Step 'flutter build windows --release'
flutter build windows --release
if ($LASTEXITCODE -ne 0) { Fail 'Windows build başarısız.' }

$release = 'build\windows\x64\runner\Release'
if (-not (Test-Path "$release\cari_takip.exe")) { Fail "$release\cari_takip.exe bulunamadı." }

# 4) MSVC çalışma zamanı DLL'leri (app-local): hedef bilgisayarda Visual C++
#    paketi kurulu olmasa da uygulama açılsın diye yanına konur.
Step 'MSVC çalışma zamanı DLL''leri ekleniyor'
foreach ($dll in 'msvcp140.dll', 'vcruntime140.dll', 'vcruntime140_1.dll') {
  $source = Join-Path $env:SystemRoot "System32\$dll"
  if (Test-Path $source) { Copy-Item $source $release -Force; Write-Host "  + $dll" }
  else { Write-Warning "$dll bulunamadı (Visual C++ Redistributable kurulu mu?)" }
}

Write-Host "`nRelease klasörünün içeriği (kısa):"
Get-ChildItem $release | Select-Object Name, Length | Format-Table -AutoSize

# 5) Kurulum dosyası
Step 'Inno Setup ile kurulum dosyası üretiliyor'
$candidates = @(
  "$env:LOCALAPPDATA\Programs\Inno Setup 6\ISCC.exe",
  "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe",
  "$env:ProgramFiles\Inno Setup 6\ISCC.exe"
)
$iscc = $candidates | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $iscc) { Fail 'Inno Setup 6 bulunamadı. https://jrsoftware.org/isdl.php adresinden kur.' }

& $iscc "/DMyAppVersion=$version" 'installer\cari_takip.iss'
if ($LASTEXITCODE -ne 0) { Fail 'Inno Setup derlemesi başarısız.' }

$setup = "installer\Output\CariTakip_Kurulum_$version.exe"
Write-Host "`nHAZIR: $setup" -ForegroundColor Green
