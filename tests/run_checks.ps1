param(
    [switch]$Windowed,
    [string]$Godot = 'E:\Godot\bin\godot.bat'
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$logRoot = Join-Path $projectRoot 'builds\phase7'
New-Item -ItemType Directory -Path $logRoot -Force | Out-Null
$originalSavePath = $env:EMBERPEAK_SAVE_PATH
$regressionId = [Guid]::NewGuid().ToString('N')
$env:EMBERPEAK_SAVE_PATH = "user://regression_$regressionId/startup/save.json"

function Invoke-GodotCheck {
    param([string]$Name, [string[]]$Arguments, [string]$Expected = '')
    $logPath = Join-Path $logRoot ($Name + '.log')
    $saveGroup = if ($Name -in @('persistence-write', 'persistence-read', 'persistence-after-death')) { 'persistence' } else { $Name }
    if ($Name -in @('phase6-services-headless', 'phase6-services-restart')) { $saveGroup = 'phase6-services' }
    if ($Name -in @('phase6-completion-write', 'phase6-completion-read')) { $saveGroup = 'phase6-completion' }
    $env:EMBERPEAK_SAVE_PATH = if ($Name -like 'persistence-*') { "user://phase5_persistence_$regressionId/$saveGroup/save.json" } else { "user://regression_$regressionId/$saveGroup/save.json" }
    if ($Name -like 'resume-combat-*') { $env:EMBERPEAK_SAVE_PATH = "user://phase5_resume_combat_$regressionId/$saveGroup/save.json" }
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
    $progression = @('--headless', '--path', $projectRoot, '--max-fps', '120', '--quit-after', '1800', '--script', 'res://tests/test_progression.gd')
    $inventory = @('--headless', '--path', $projectRoot, '--max-fps', '120', '--quit-after', '1800', '--script', 'res://tests/test_inventory.gd')
    $weapons = @('--headless', '--path', $projectRoot, '--max-fps', '120', '--quit-after', '3000', '--script', 'res://tests/test_weapons.gd')
    $saveFile = @('--headless', '--path', $projectRoot, '--max-fps', '120', '--quit-after', '2400', '--script', 'res://tests/test_save_file.gd')
    $snapshotCodec = @('--headless', '--path', $projectRoot, '--max-fps', '120', '--quit-after', '1800', '--script', 'res://tests/test_snapshot_codec.gd')
    $runSnapshot = @('--headless', '--path', $projectRoot, '--max-fps', '120', '--quit-after', '1800', '--script', 'res://tests/test_run_snapshot.gd')
    $session = @('--headless', '--path', $projectRoot, '--max-fps', '120', '--quit-after', '1800', '--script', 'res://tests/test_session.gd')
    $phase5Flow = @('--headless', '--path', $projectRoot, '--max-fps', '120', '--quit-after', '5000', '--script', 'res://tests/test_phase5_flow.gd')
    Invoke-GodotCheck 'progression-headless' $progression 'PROGRESSION_CHECKS_PASSED=78'
    Invoke-GodotCheck 'inventory-headless' $inventory 'INVENTORY_CHECKS_PASSED=58'
    Invoke-GodotCheck 'weapons-headless' $weapons 'WEAPON_CHECKS_PASSED=26'
    Invoke-GodotCheck 'save-file-headless' $saveFile 'SAVE_FILE_CHECKS_PASSED=156'
    Invoke-GodotCheck 'snapshot-codec-headless' $snapshotCodec 'SNAPSHOT_CODEC_CHECKS_PASSED=96'
    Invoke-GodotCheck 'run-snapshot-headless' $runSnapshot 'RUN_SNAPSHOT_PASSED=32'
    Invoke-GodotCheck 'session-headless' $session 'SESSION_CHECKS_PASSED=8'
    Invoke-GodotCheck 'phase5-flow-headless' $phase5Flow 'PHASE5_FLOW_PASSED=17'
    $phase6Services = @('--headless', '--path', $projectRoot, '--max-fps', '120', '--quit-after', '3000', '--script', 'res://tests/test_phase6_services.gd')
    $phase6Flow = @('--headless', '--path', $projectRoot, '--max-fps', '120', '--quit-after', '6000', '--script', 'res://tests/test_phase6_flow.gd')
    Invoke-GodotCheck 'phase6-services-headless' $phase6Services 'PHASE6_SERVICES_PASSED=26'
    Invoke-GodotCheck 'phase6-services-restart' ($phase6Services + @('--', '--restart')) 'PHASE6_SERVICES_RESTART_OK'
    Invoke-GodotCheck 'phase6-flow-headless' $phase6Flow 'PHASE6_FLOW_PASSED=59'
    Invoke-GodotCheck 'phase6-completion-write' ($phase6Flow + @('--', '--completion-write')) 'COMPLETION_WRITE_OK'
    Invoke-GodotCheck 'phase6-completion-read' ($phase6Flow + @('--', '--completion-read')) 'COMPLETION_READ_OK'
    $stability = @('--headless', '--path', $projectRoot, '--max-fps', '120', '--quit-after', '6000', '--script', 'res://tests/test_release_stability.gd')
    Invoke-GodotCheck 'release-stability-headless' $stability 'RELEASE_STABILITY_PASSED=62'
    $resumeCombat = @('--headless', '--path', $projectRoot, '--max-fps', '120', '--quit-after', '5000', '--script', 'res://tests/test_resume_combat.gd')
    $persistence = @('--headless', '--path', $projectRoot, '--max-fps', '120', '--quit-after', '5000', '--script', 'res://tests/test_phase5_persistence.gd')
    Invoke-GodotCheck 'resume-combat-headless' $resumeCombat 'RESUME_COMBAT_CHECKS_PASSED=15'
    Invoke-GodotCheck 'persistence-write' ($persistence + @('--', '--write')) 'PERSIST_WRITE_OK'
    Invoke-GodotCheck 'persistence-read' ($persistence + @('--', '--read')) 'PERSIST_READ_OK'
    Invoke-GodotCheck 'persistence-after-death' ($persistence + @('--', '--after-death')) 'PERSIST_AFTER_DEATH_OK'
    Invoke-GodotCheck 'persistence-failures' ($persistence + @('--', '--failures')) 'PERSIST_FAILURES_OK'
    $settingsArgs = @('--headless', '--path', $projectRoot, '--max-fps', '120', '--quit-after', '1800', '--script', 'res://tests/test_settings.gd')
    Invoke-GodotCheck 'settings-headless' $settingsArgs 'SETTINGS_CHECKS_PASSED=6'
    $restart = @('--headless', '--path', $projectRoot, '--script', 'res://tests/test_settings_restart.gd')
    Invoke-GodotCheck 'restart-write' ($restart + @('--', '--write')) 'RESTART_WRITE_OK'
    Invoke-GodotCheck 'restart-read' ($restart + @('--', '--read')) 'RESTART_READ_OK'
    if ($Windowed) {
        Invoke-GodotCheck 'release-stability-window' ($stability | Where-Object { $_ -ne '--headless' }) 'RELEASE_STABILITY_PASSED=62'
        Invoke-GodotCheck 'phase6-services-window' ($phase6Services | Where-Object { $_ -ne '--headless' }) 'PHASE6_SERVICES_PASSED=26'
        Invoke-GodotCheck 'phase6-flow-window' ($phase6Flow | Where-Object { $_ -ne '--headless' }) 'PHASE6_FLOW_PASSED=59'
        Invoke-GodotCheck 'weapons-window' ($weapons | Where-Object { $_ -ne '--headless' }) 'WEAPON_CHECKS_PASSED=26'
        Invoke-GodotCheck 'phase5-flow-window' ($phase5Flow | Where-Object { $_ -ne '--headless' }) 'PHASE5_FLOW_PASSED=17'
        Invoke-GodotCheck 'resume-combat-window' ($resumeCombat | Where-Object { $_ -ne '--headless' }) 'RESUME_COMBAT_CHECKS_PASSED=15'
        Invoke-GodotCheck 'persistence-failures-window' (($persistence | Where-Object { $_ -ne '--headless' }) + @('--', '--failures')) 'PERSIST_FAILURES_OK'
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
    $env:EMBERPEAK_SAVE_PATH = $originalSavePath
    if ($preferencesExisted) {
        [IO.File]::WriteAllBytes($preferencesPath, $originalBytes)
    } elseif (Test-Path -LiteralPath $preferencesPath) {
        Remove-Item -LiteralPath $preferencesPath
    }
}
