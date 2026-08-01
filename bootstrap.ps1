$ErrorActionPreference = "Stop"

function Require-Command {
    param([string]$Name)
    if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
        throw "La commande '$Name' est introuvable. Installe Flutter et ajoute-le au PATH."
    }
}

Require-Command "flutter"

$root = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $root

Write-Host "Création du squelette Flutter..." -ForegroundColor Cyan

$backup = Join-Path $env:TEMP ("autoclair_source_" + [Guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $backup | Out-Null

$itemsToPreserve = @(
    "lib",
    "test",
    "pubspec.yaml",
    "analysis_options.yaml",
    "README.md",
    "run_dev.ps1",
    "bootstrap.ps1"
)

foreach ($item in $itemsToPreserve) {
    $source = Join-Path $root $item
    if (Test-Path $source) {
        Copy-Item $source -Destination $backup -Recurse -Force
    }
}

flutter create `
    --project-name autoclair_app `
    --org fr.autoclair `
    --platforms android,ios,web,windows `
    .

foreach ($item in $itemsToPreserve) {
    $source = Join-Path $backup $item
    if (Test-Path $source) {
        $destination = Join-Path $root $item
        if (Test-Path $destination) {
            Remove-Item $destination -Recurse -Force
        }
        Copy-Item $source -Destination $destination -Recurse -Force
    }
}

Remove-Item $backup -Recurse -Force

$manifestPath = Join-Path $root "android/app/src/main/AndroidManifest.xml"
if (Test-Path $manifestPath) {
    $manifest = Get-Content -LiteralPath $manifestPath -Raw
    if ($manifest -notmatch "android.permission.INTERNET") {
        $manifest = $manifest -replace `
            '(<manifest[^>]*>)', `
            "`$1`r`n    <uses-permission android:name=`"android.permission.INTERNET`" />"
        Set-Content -LiteralPath $manifestPath -Value $manifest -Encoding UTF8
    }
}

Write-Host "Installation des dépendances..." -ForegroundColor Cyan
flutter pub get

Write-Host "Formatage du code..." -ForegroundColor Cyan
dart format lib test

Write-Host "Analyse statique..." -ForegroundColor Cyan
flutter analyze

Write-Host "Tests..." -ForegroundColor Cyan
flutter test

Write-Host ""
Write-Host "AutoClair est prêt." -ForegroundColor Green
Write-Host "Renseigne les deux variables Supabase puis lance .\run_dev.ps1"
