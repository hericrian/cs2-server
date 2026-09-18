$ErrorActionPreference = 'Stop'
$workspace = Split-Path -Parent $MyInvocation.MyCommand.Path
$csgo = 'D:\CS2Server\game\game\csgo'
if (-not (Test-Path -LiteralPath (Join-Path $csgo 'gameinfo.gi'))) {
    throw "Instalacao do CS2 nao encontrada em $csgo"
}
$addons = Join-Path $csgo 'addons'
New-Item -ItemType Directory -Path $addons -Force | Out-Null

$packages = @(
    'D:\CS2Server\staging\mmsource-2.0.0-git1460-windows\addons',
    'D:\CS2Server\staging\counterstrikesharp-with-runtime-windows-1.0.374\addons',
    'D:\CS2Server\staging\RetakesPlugin-3.1.1\addons'
)
foreach ($package in $packages) {
    Copy-Item -Path (Join-Path $package '*') -Destination $addons -Recurse -Force
}

$pluginDir = Join-Path $addons 'counterstrikesharp\plugins\ModeChooser'
New-Item -ItemType Directory -Path $pluginDir -Force | Out-Null
Copy-Item -LiteralPath (Join-Path $workspace 'ModeChooser\bin\Release\net10.0\ModeChooser.dll') -Destination $pluginDir -Force

$gameInfo = Join-Path $csgo 'gameinfo.gi'
$content = Get-Content -LiteralPath $gameInfo -Raw
if ($content -notmatch 'Game\s+csgo/addons/metamod') {
    Copy-Item -LiteralPath $gameInfo -Destination "$gameInfo.before-metamod" -Force
    $match = 'Game_LowViolence\s+csgo_lv[^\r\n]*'
    $content = [regex]::Replace($content, $match, '$0' + "`r`n`t`t`tGame`tcsgo/addons/metamod", 1)
    Set-Content -LiteralPath $gameInfo -Value $content -Encoding UTF8
}

$cfgDir = Join-Path $csgo 'cfg'
New-Item -ItemType Directory -Path $cfgDir -Force | Out-Null
Copy-Item -LiteralPath (Join-Path $workspace 'server.cfg') -Destination (Join-Path $cfgDir 'server.cfg') -Force
Write-Host 'Metamod, CounterStrikeSharp, Retakes e ModeChooser instalados.'
