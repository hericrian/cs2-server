$ErrorActionPreference = 'Continue'
$root = Split-Path -Parent $MyInvocation.MyCommand.Path

Write-Host ''
Write-Host '===== SERVIDOR CS2 DO VOLTZ =====' -ForegroundColor Cyan
Write-Host ''

# 1) Tunel do WireGuard (leva o trafego ate a maquina de Sao Paulo).
$tunel = Get-Service 'WireGuardTunnel$cs2-relay' -ErrorAction SilentlyContinue
if (-not $tunel) {
    Write-Host '[!] Tunel WireGuard nao encontrado. O endereco de Sao Paulo nao vai funcionar.' -ForegroundColor Yellow
} elseif ($tunel.Status -ne 'Running') {
    Write-Host '[~] Tunel parado; tentando ligar (pode pedir permissao)...' -ForegroundColor Yellow
    Start-Process powershell.exe -Verb RunAs -ArgumentList '-NoProfile','-Command','Start-Service "WireGuardTunnel$cs2-relay"' -Wait -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 4
    $tunel.Refresh()
    Write-Host ("[{0}] Tunel: {1}" -f $(if ($tunel.Status -eq 'Running') { 'ok' } else { '!' }), $tunel.Status)
} else {
    Write-Host '[ok] Tunel para Sao Paulo ligado.' -ForegroundColor Green
}

# 2) playit, so como caminho reserva.
$playit = 'C:\Program Files\playit_gg\bin\playit.exe'
if (Test-Path -LiteralPath $playit) {
    if (Get-Process playit -ErrorAction SilentlyContinue) {
        Write-Host '[ok] playit ja rodando (caminho reserva).' -ForegroundColor Green
    } else {
        Start-Process -FilePath $playit -ArgumentList '-s','start' -WindowStyle Hidden `
            -RedirectStandardOutput 'D:\CS2Server\logs\playit-out.log' -RedirectStandardError 'D:\CS2Server\logs\playit-error.log' | Out-Null
        Write-Host '[ok] playit iniciado (caminho reserva).' -ForegroundColor Green
    }
}

# 3) Servidor do jogo e os auxiliares do chat.
Write-Host ''
& (Join-Path $root 'start-server.ps1')

# 4) Espera o servidor responder antes de liberar os enderecos.
Write-Host ''
Write-Host 'Aguardando o mapa carregar...' -NoNewline
$pronto = $false
for ($i = 0; $i -lt 30; $i++) {
    Start-Sleep -Seconds 3
    $u = [Net.Sockets.UdpClient]::new(); $u.Client.ReceiveTimeout = 1500
    try {
        $q = [byte[]](0xFF,0xFF,0xFF,0xFF,0x54) + [Text.Encoding]::ASCII.GetBytes('Source Engine Query') + [byte[]](0)
        [void]$u.Send($q, $q.Length, '127.0.0.1', 27015)
        $ep = [Net.IPEndPoint]::new([Net.IPAddress]::Any, 0)
        [void]$u.Receive([ref]$ep)
        $pronto = $true
    } catch { Write-Host '.' -NoNewline } finally { $u.Dispose() }
    if ($pronto) { break }
}
Write-Host ''

$ipLocal = (Get-NetIPConfiguration |
    Where-Object { $_.IPv4DefaultGateway -and $_.NetAdapter.Status -eq 'Up' -and
                   $_.InterfaceAlias -notmatch 'Radmin|VirtualBox|VMware|cs2-relay|WireGuard|Hyper-V|Loopback' } |
    Select-Object -First 1).IPv4Address.IPAddress

Write-Host ''
if ($pronto) { Write-Host '===== SERVIDOR NO AR =====' -ForegroundColor Green }
else { Write-Host '===== SERVIDOR DEMOROU A RESPONDER, confira o log =====' -ForegroundColor Yellow }
Write-Host ''
Write-Host 'Manda para os amigos:' -ForegroundColor Cyan
Write-Host '   connect 147.15.45.159:27015      (Sao Paulo, sem instalar nada)'
Write-Host '   connect 26.134.21.0:27015        (Radmin VPN)'
Write-Host '   connect expressing-ghz.tun.ply.gg:22052   (reserva)'
if ($ipLocal) { Write-Host "   connect ${ipLocal}:27015           (quem esta na sua casa)" }
Write-Host ''
Write-Host 'No jogo: /ajuda mostra todos os comandos do chat.'
Write-Host 'Para desligar tudo depois, use o Parar servidor.cmd na pasta dos scripts.'
Write-Host ''
Write-Host 'Pode fechar esta janela; o servidor fica rodando na janela minimizada "cs2".'
Write-Host ''
Read-Host 'Aperte Enter para fechar'
