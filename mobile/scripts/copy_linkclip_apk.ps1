# Copy Flutter default APKs to shareable LinkClip-*.apk names.
# Usage (from mobile/):
#   .\scripts\copy_linkclip_apk.ps1
#   .\scripts\copy_linkclip_apk.ps1 -BuildType release

param(
  [ValidateSet("debug", "release", "both")]
  [string]$BuildType = "both"
)

$ErrorActionPreference = "Stop"
$outDir = Join-Path $PSScriptRoot "..\build\app\outputs\flutter-apk" | Resolve-Path -ErrorAction SilentlyContinue
if (-not $outDir) {
  Write-Error "APK output folder not found. Build first: flutter build apk --release"
}

function Copy-LinkClipApk([string]$type) {
  $src = Join-Path $outDir "app-$type.apk"
  $dst = Join-Path $outDir "LinkClip-$type.apk"
  if (-not (Test-Path $src)) {
    Write-Warning "Missing $src"
    return
  }
  Copy-Item -Path $src -Destination $dst -Force
  Write-Host "Copied $($src | Split-Path -Leaf) -> $($dst | Split-Path -Leaf)"
}

if ($BuildType -eq "both") {
  Copy-LinkClipApk "debug"
  Copy-LinkClipApk "release"
} else {
  Copy-LinkClipApk $BuildType
}
