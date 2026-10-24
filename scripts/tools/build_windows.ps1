param(
    [string]$Godot = 'E:\Godot\bin\godot.bat',
    [switch]$PackOnly
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$outputRoot = Join-Path $projectRoot 'builds\windows'
$logRoot = Join-Path $projectRoot 'builds\phase7'
New-Item -ItemType Directory -Path $outputRoot, $logRoot -Force | Out-Null
$mode = if ($PackOnly) { '--export-pack' } else { '--export-release' }
$outputPath = Join-Path $outputRoot $(if ($PackOnly) { 'EmberpeakDao.pck' } else { 'EmberpeakDao.exe' })
$logPath = Join-Path $logRoot $(if ($PackOnly) { 'export-pack.log' } else { 'export-windows.log' })
& $Godot --headless --path $projectRoot $mode 'Windows Desktop' $outputPath *> $logPath
$exportExit = $LASTEXITCODE
$exportText = Get-Content -LiteralPath $logPath -Raw
$success = $exportExit -eq 0 -and $exportText -notmatch 'SCRIPT ERROR|Parse Error|ERROR:' -and (Test-Path -LiteralPath $outputPath)
if ($success) { $success = (Get-Item -LiteralPath $outputPath).Length -gt 0 }
if ($success -and -not $PackOnly) { $success = Test-Path -LiteralPath (Join-Path $outputRoot 'EmberpeakDao.pck') }
$record = [ordered]@{Mode=$mode; ExitCode=$exportExit; Success=$success; Output=$outputPath; Log=$logPath; StandaloneExecutableProduced=$success -and -not $PackOnly; RuntimeVerified=$false}
$record | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $logRoot $(if ($PackOnly) { 'export-pack-result.json' } else { 'export-windows-result.json' })) -Encoding UTF8
if (-not $success) {
    Write-Output $exportText
    Write-Output '导出未成功；未验证独立Windows运行。请查看日志与WINDOWS_RELEASE.md。'
    exit 1
}
Write-Output $(if ($PackOnly) { "PCK资源包已导出（不是独立exe）：$outputPath" } else { "Windows导出文件已生成，仍须实际启动验收：$outputPath" })
