param(
  [string]$OutputDirectory = "dist"
)

$ErrorActionPreference = "Stop"

$scriptDirectory = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectRoot = Split-Path -Parent $scriptDirectory
$releaseDirectory = Join-Path $projectRoot "build\windows\x64\runner\Release"
$outputPath = Join-Path $projectRoot $OutputDirectory
$zipPath = Join-Path $outputPath "PasswordVault-Windows.zip"

Set-Location $projectRoot

flutter pub get
flutter build windows --release

if (!(Test-Path $releaseDirectory)) {
  throw "Windows release build was not found at $releaseDirectory"
}

New-Item -ItemType Directory -Force -Path $outputPath | Out-Null

if (Test-Path $zipPath) {
  Remove-Item $zipPath -Force
}

Compress-Archive -Path (Join-Path $releaseDirectory "*") -DestinationPath $zipPath -Force

Write-Host "Created $zipPath"
