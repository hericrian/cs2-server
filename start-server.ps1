$ErrorActionPreference = 'Stop'
$root = 'D:\CS2Server\game'
$exe = Join-Path $root 'game\bin\win64\cs2.exe'
if (-not (Test-Path -LiteralPath $exe)) { throw "CS2 nao encontrado em $exe" }

$existing = Get-CimInstance Win32_Process | Where-Object {
    $_.Name -eq 'cs2.exe' -and $_.CommandLine -like '*-dedicated*'
}
$logDir = 'D:\CS2Server\logs'
New-Item -ItemType Directory -Path $logDir -Force | Out-Null
$workspace = Split-Path -Parent $MyInvocation.MyCommand.Path

function Ensure-Helper([string]$name) {
    $pidFile = Join-Path $logDir "$name.pid"
    if (Test-Path -LiteralPath $pidFile) {
        $oldPid = [int](Get-Content -LiteralPath $pidFile -Raw)
        # Apos reiniciar o PC o PID antigo pode pertencer a outro processo.
        $old = Get-CimInstance Win32_Process -Filter "ProcessId = $oldPid" -ErrorAction SilentlyContinue
        if ($old -and $old.CommandLine -like "*$name.ps1*") { return }
    }
    $script = Join-Path $workspace "$name.ps1"
    $helper = Start-Process -FilePath 'powershell.exe' -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$script`"" -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $logDir "$name-out.log") -RedirectStandardError (Join-Path $logDir "$name-error.log")
    Set-Content -LiteralPath $pidFile -Value $helper.Id
    Write-Host "$name iniciado. PID: $($helper.Id)"
}

Ensure-Helper 'chat-receiver'
Start-Sleep -Seconds 1
if ($existing) {
    Write-Host "Servidor ja em execucao. PID: $($existing.ProcessId -join ', ')"
    Ensure-Helper 'mode-controller'
    return
}

$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
# A janela do servidor fica minimizada de proposito: com console de verdade o CS2
# para de escrever ~60 linhas de erro por segundo no log, o que causava travadas.
$console = Join-Path $root 'game\csgo\console.log'
if (Test-Path -LiteralPath $console) { Move-Item -LiteralPath $console -Destination (Join-Path $logDir "$stamp-console.log") -Force }
$args = '-dedicated -console -condebug -usercon -port 27015 -maxplayers 10 +sv_lan 0 +game_type 0 +game_mode 0 +map de_mirage +exec server.cfg'
$process = Start-Process -FilePath $exe -ArgumentList $args -WorkingDirectory (Join-Path $root 'game\bin\win64') -WindowStyle Minimized -PassThru
# Prioridade alta: evita os travamentos de quadro quando o jogo roda no mesmo PC.
try { $process.PriorityClass = [Diagnostics.ProcessPriorityClass]::High } catch { Write-Host "Nao foi possivel elevar a prioridade: $($_.Exception.Message)" }
Write-Host "Servidor iniciado. PID: $($process.Id)"
Write-Host 'A janela minimizada "cs2" e o servidor. Fechar aquela janela derruba o servidor.'
Write-Host "Log ao vivo: $console"
# O IP da rede local vem do DHCP e muda quando o PC reinicia; por isso e lido na hora.
# Radmin, VirtualBox e o tunel tambem tem gateway, entao sao descartados aqui.
$ipLocal = (Get-NetIPConfiguration |
    Where-Object { $_.IPv4DefaultGateway -and $_.NetAdapter.Status -eq 'Up' -and
                   $_.InterfaceAlias -notmatch 'Radmin|VirtualBox|VMware|cs2-relay|WireGuard|Hyper-V|Loopback' } |
    Sort-Object { $_.IPv4DefaultGateway.RouteMetric } |
    Select-Object -First 1).IPv4Address.IPAddress
if (-not $ipLocal) { $ipLocal = '(nao detectado)' }
$ipRadmin = (Get-NetIPAddress -InterfaceAlias 'Radmin VPN' -AddressFamily IPv4 -ErrorAction SilentlyContinue | Select-Object -First 1).IPAddress
Write-Host "Rede local: connect ${ipLocal}:27015"
Write-Host 'Amigos e faculdade (rele em Sao Paulo): connect 147.15.45.159:27015'
if ($ipRadmin) { Write-Host "Alternativa pelo Radmin VPN: connect ${ipRadmin}:27015" }
$tunel = Get-Service 'WireGuardTunnel$cs2-relay' -ErrorAction SilentlyContinue
if ($tunel -and $tunel.Status -ne 'Running') {
    Write-Host 'ATENCAO: o tunel WireGuard esta parado; o endereco de Sao Paulo nao vai funcionar.'
}
Ensure-Helper 'mode-controller'
