$ErrorActionPreference = 'Stop'

$projectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$releaseCandidates = @(
    (Join-Path $projectRoot 'build\windows\x64\runner\Release'),
    (Join-Path $projectRoot 'build\windows\runner\Release')
)

$releaseDir = $releaseCandidates | Where-Object {
    Test-Path (Join-Path $_ 'code_bridge_mini.exe')
} | Select-Object -First 1

if (-not $releaseDir) {
    throw 'Не найден release bundle. Сначала выполните: flutter build windows --release'
}

$portableRoot = Join-Path $projectRoot 'portable'
$portableApp = Join-Path $portableRoot 'code_bridge_mini'
$zipPath = Join-Path $portableRoot 'CodeBridgeMini-Windows-x64.zip'

New-Item -ItemType Directory -Force -Path $portableRoot | Out-Null
if (Test-Path $portableApp) {
    Remove-Item -LiteralPath $portableApp -Recurse -Force
}
New-Item -ItemType Directory -Force -Path $portableApp | Out-Null

Copy-Item -Path (Join-Path $releaseDir '*') -Destination $portableApp -Recurse -Force

$trayIconSource = Join-Path $projectRoot 'assets\tray.ico'
if (-not (Test-Path $trayIconSource)) {
    throw "Не найден значок системного трея: $trayIconSource"
}
Copy-Item -LiteralPath $trayIconSource -Destination (Join-Path $portableApp 'tray.ico') -Force

New-Item -ItemType Directory -Force -Path (Join-Path $portableApp 'data\projects') | Out-Null

if (Test-Path $zipPath) {
    Remove-Item -LiteralPath $zipPath -Force
}
Compress-Archive -Path $portableApp -DestinationPath $zipPath -CompressionLevel Optimal

Write-Host "Portable-папка: $portableApp"
Write-Host "ZIP-архив:      $zipPath"
