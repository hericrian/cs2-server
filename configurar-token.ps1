$ErrorActionPreference = 'Stop'
$workspace = Split-Path -Parent $MyInvocation.MyCommand.Path
$privateConfig = 'D:\CS2Server\game\game\csgo\cfg\server-private.cfg'

Write-Host 'Cole o codigo de sessao gerado em steamcommunity.com/dev/managegameservers e aperte Enter.'
Write-Host '(O codigo aparece como asteriscos.)'
$secure = Read-Host 'Codigo' -AsSecureString
$bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
try { $token = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr).Trim() }
finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr) }
if ($token -notmatch '^[0-9A-Fa-f]{32}$') { throw 'Codigo invalido: deve ter 32 caracteres (0-9 e A-F).' }

$lines = @(Get-Content -LiteralPath $privateConfig | Where-Object { $_ -notmatch '^\s*sv_setsteamaccount\b' })
$lines += "sv_setsteamaccount `"$token`""
[IO.File]::WriteAllLines($privateConfig, [string[]]$lines, [Text.UTF8Encoding]::new($false))
Write-Host 'Codigo gravado. Reiniciando o servidor...'

& (Join-Path $workspace 'stop-server.ps1')
for ($i = 0; $i -lt 30; $i++) {
    $running = Get-CimInstance Win32_Process | Where-Object { $_.Name -eq 'cs2.exe' -and $_.CommandLine -like '*-dedicated*' }
    if (-not $running) { break }
    Start-Sleep -Seconds 1
}
& (Join-Path $workspace 'start-server.ps1')
