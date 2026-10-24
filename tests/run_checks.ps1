param(
    [switch]$Windowed,
    [string]$Godot = 'E:\Godot\bin\godot.bat'
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$logRoot = Join-Path $projectRoot 'builds\phase4'
New-Item -ItemType Directory -Path $logRoot -Force | Out-Null

function Invoke-GodotCheck {
    param([string]$Name, [string[]]$Arguments, [string]$Expected = '')
    $logPath = Join-Path $logRoot ($Name + '.log')
    & $Godot @Arguments *> $logPath
    $exitCode = $LASTEXITCODE
    $output = Get-Content -LiteralPath $logPath -Raw
    if ($exitCode -ne 0 -or $output -match 'SCRIPT ERROR|Parse Error|ERROR:' -or
        ($Expected -and $output -notmatch [regex]::Escape($Expected))) {
        throw "$Name 失败：退出码 $exitCode`n$output"
    }
    Write-Host "通过：$Name"
}

$location = & $Godot --headless --path $projectRoot --script res://tests/test_settings_restart.gd 2>&1 | Out-String
if ($LASTEXITCODE -ne 0 -or $location -match 'SCRIPT ERROR|Parse Error|ERROR:') { throw $location }
$match = [regex]::Match($location, 'SETTINGS_FILE=([^\r\n]+)')
if (-not $match.Success) { throw '无法定位用户设置文件。' }
$preferencesPath = $match.Groups[1].Value.Trim()
$preferencesExisted = Test-Path -LiteralPath $preferencesPath
$originalBytes = if ($preferencesExisted) { [IO.File]::ReadAllBytes($preferencesPath) } else { $null }

try {
    Invoke-GodotCheck 'import-final' @('--headless', '--path', $projectRoot, '--import')
    $scripts = @(Get-ChildItem -LiteralPath (Join-Path $projectRoot 'scripts'), $PSScriptRoot -Recurse -Filter '*.gd')
    foreach ($script in $scripts) {
        $relative = [IO.Path]::GetRelativePath($projectRoot, $script.FullName).Replace('\', '/')
        Invoke-GodotCheck ('parse-' + $script.BaseName) @('--headless', '--path', $projectRoot, '--check-only', '--script', "res://$relative")
    }
    Invoke-GodotCheck 'startup-headless' @('--headless', '--path', $projectRoot, '--max-fps', '120', '--quit-after', '120')
    $flow = @('--headless', '--path', $projectRoot, '--max-fps', '120', '--quit-after', '1800', '--script', 'res://tests/test_framework.gd')
    Invoke-GodotCheck 'framework-headless' $flow 'FRAMEWORK_CHECKS_PASSED=24'
    Invoke-GodotCheck 'quit-from-pause' ($flow + @('--', '--quit-from-pause')) 'FRAMEWORK_CHECKS_PASSED=24'
    $combat = @('--headless', '--path', $projectRoot, '--max-fps', '120', '--quit-after', '2400', '--script', 'res://tests/test_combat.gd')
    Invoke-GodotCheck 'combat-headless' $combat 'COMBAT_CHECKS_PASSED=28'
    $artRoom = @('--headless', '--path', $projectRoot, '--max-fps', '120', '--quit-after', '2400', '--script', 'res://tests/test_art_room.gd')
    Invoke-GodotCheck 'art-room-headless' $artRoom 'ART_ROOM_CHECKS_PASSED=24'
    $playerArt = @('--headless', '--path', $projectRoot, '--max-fps', '120', '--quit-after', '1200', '--script', 'res://tests/test_player_art.gd')
    Invoke-GodotCheck 'player-art-headless' $playerArt 'PLAYER_ART_CHECKS_PASSED=20'
    $actorAnimation = @('--headless', '--path', $projectRoot, '--max-fps', '120', '--quit-after', '1800', '--script', 'res://tests/test_actor_animation.gd')
    Invoke-GodotCheck 'actor-animation-headless' $actorAnimation 'ACTOR_ANIMATION_CHECKS_PASSED=68'
    $paintedMap = @('--headless', '--path', $projectRoot, '--max-fps', '120', '--quit-after', '2400', '--script', 'res://tests/test_painted_map.gd')
    Invoke-GodotCheck 'painted-map-headless' $paintedMap 'PAINTED_MAP_CHECKS_PASSED=27'
    $allArt = @('--headless', '--path', $projectRoot, '--max-fps', '120', '--quit-after', '2400', '--script', 'res://tests/test_all_art.gd')
    Invoke-GodotCheck 'all-art-headless' $allArt 'ALL_ART_CHECKS_PASSED=96'
    # 6000帧上限下窗口检查曾完成47项断言但未获结束标记，保留有界退出并留出余量。
    $enemies = @('--headless', '--path', $projectRoot, '--max-fps', '120', '--quit-after', '9000', '--script', 'res://tests/test_enemies.gd')
    $route = @('--headless', '--path', $projectRoot, '--max-fps', '120', '--quit-after', '3600', '--script', 'res://tests/test_route.gd')
    $regressions = @('--headless', '--path', $projectRoot, '--max-fps', '120', '--quit-after', '1600', '--script', 'res://tests/test_enemy_regressions.gd')
    Invoke-GodotCheck 'enemies-headless' $enemies 'ENEMY_CHECKS_PASSED=47'
    Invoke-GodotCheck 'route-headless' $route 'ROUTE_CHECKS_PASSED=41'
    Invoke-GodotCheck 'enemy-regressions-headless' $regressions 'ENEMY_REGRESSIONS_PASSED=6'
    $runGraph = @('--headless', '--path', $projectRoot, '--max-fps', '120', '--quit-after', '10000', '--script', 'res://tests/test_run_graph.gd')
    $runState = @('--headless', '--path', $projectRoot, '--max-fps', '120', '--quit-after', '2400', '--script', 'res://tests/test_run_state.gd')
    $runFlow = @('--headless', '--path', $projectRoot, '--max-fps', '120', '--quit-after', '5000', '--script', 'res://tests/test_roguelite_flow.gd')
    $runRuntime = @('--headless', '--path', $projectRoot, '--max-fps', '120', '--quit-after', '2400', '--script', 'res://tests/test_run_runtime.gd')
    Invoke-GodotCheck 'run-graph-headless' $runGraph 'RUN_GRAPH_CHECKS_PASSED=8919'
    Invoke-GodotCheck 'run-state-headless' $runState 'RUN_STATE_CHECKS_PASSED=57'
    Invoke-GodotCheck 'roguelite-flow-headless' $runFlow 'ROGUELITE_FLOW_PASSED=36'
    Invoke-GodotCheck 'run-runtime-headless' $runRuntime 'RUN_RUNTIME_PASSED=15'
    $settingsArgs = @('--headless', '--path', $projectRoot, '--max-fps', '120', '--quit-after', '1800', '--script', 'res://tests/test_settings.gd')
    Invoke-GodotCheck 'settings-headless' $settingsArgs 'SETTINGS_CHECKS_PASSED=6'
    $restart = @('--headless', '--path', $projectRoot, '--script', 'res://tests/test_settings_restart.gd')
    Invoke-GodotCheck 'restart-write' ($restart + @('--', '--write')) 'RESTART_WRITE_OK'
    Invoke-GodotCheck 'restart-read' ($restart + @('--', '--read')) 'RESTART_READ_OK'
    if ($Windowed) {
        Invoke-GodotCheck 'run-graph-window' ($runGraph | Where-Object { $_ -ne '--headless' }) 'RUN_GRAPH_CHECKS_PASSED=8919'
        Invoke-GodotCheck 'roguelite-flow-window' ($runFlow | Where-Object { $_ -ne '--headless' }) 'ROGUELITE_FLOW_PASSED=36'
        Invoke-GodotCheck 'run-runtime-window' ($runRuntime | Where-Object { $_ -ne '--headless' }) 'RUN_RUNTIME_PASSED=15'
        $screenshots = Join-Path $logRoot 'screenshots'
        $windowFlow = $flow | Where-Object { $_ -ne '--headless' }
        Invoke-GodotCheck 'framework-window' ($windowFlow + @('--', "--screenshots=$screenshots")) 'FRAMEWORK_CHECKS_PASSED=24'
        Invoke-GodotCheck 'combat-window' ($combat | Where-Object { $_ -ne '--headless' }) 'COMBAT_CHECKS_PASSED=28'
        Invoke-GodotCheck 'art-room-window' ($artRoom | Where-Object { $_ -ne '--headless' }) 'ART_ROOM_CHECKS_PASSED=24'
        Invoke-GodotCheck 'player-art-window' ($playerArt | Where-Object { $_ -ne '--headless' }) 'PLAYER_ART_CHECKS_PASSED=20'
        Invoke-GodotCheck 'actor-animation-window' ($actorAnimation | Where-Object { $_ -ne '--headless' }) 'ACTOR_ANIMATION_CHECKS_PASSED=68'
        Invoke-GodotCheck 'painted-map-window' ($paintedMap | Where-Object { $_ -ne '--headless' }) 'PAINTED_MAP_CHECKS_PASSED=27'
        Invoke-GodotCheck 'all-art-window' ($allArt | Where-Object { $_ -ne '--headless' }) 'ALL_ART_CHECKS_PASSED=96'
        Invoke-GodotCheck 'enemies-window' ($enemies | Where-Object { $_ -ne '--headless' }) 'ENEMY_CHECKS_PASSED=47'
        Invoke-GodotCheck 'route-window' ($route | Where-Object { $_ -ne '--headless' }) 'ROUTE_CHECKS_PASSED=41'
        Invoke-GodotCheck 'enemy-regressions-window' ($regressions | Where-Object { $_ -ne '--headless' }) 'ENEMY_REGRESSIONS_PASSED=6'
        Invoke-GodotCheck 'settings-window'  ($settingsArgs | Where-Object { $_ -ne '--headless' }) 'SETTINGS_CHECKS_PASSED=10'
    }
    Write-Host "全部框架、战斗、美术、敌人、地图与肉鸽检查通过；逐脚本解析 $($scripts.Count) 项。日志：$logRoot"
}
finally {
    if ($preferencesExisted) {
        [IO.File]::WriteAllBytes($preferencesPath, $originalBytes)
    } elseif (Test-Path -LiteralPath $preferencesPath) {
        Remove-Item -LiteralPath $preferencesPath
    }
}
