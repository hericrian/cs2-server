$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$query = Join-Path $root 'query-server.ps1'
$logPath = 'D:\CS2Server\logs\chat-controller.log'
$owner = $null
$mode = $null
$listener = [Net.HttpListener]::new()
$listener.Prefixes.Add('http://127.0.0.1:28015/')
$listener.Start()

function Log([string]$text) {
    Add-Content -LiteralPath $logPath -Value ("$(Get-Date -Format o) $text")
}
function Rcon([string]$command) {
    try { return (& $query $command 2>$null | Out-String).Trim() } catch { Log "RCON: $($_.Exception.Message)"; return '' }
}
function Broadcast([string]$message) {
    # As mensagens sao constantes ou da lista fixa de modos; nenhum texto do chat entra no RCON.
    [void](Rcon ('say "' + $message + '"'))
}
function Handle-Line([string]$line) {
    $identity = [regex]::Match($line, '"[^"\r\n]*<\d+><(?<steam>\[U:1:\d+\]|STEAM_\d+:\d+:\d+|7656119\d+)><[^>]*>"')
    if (-not $identity.Success) { return }
    $steam = $identity.Groups['steam'].Value
    if ($line -match '" (entered the game|connected)') {
        if (-not $owner) {
            $script:owner = $steam
            Log "Primeiro jogador: $steam"
            Broadcast 'Primeiro jogador: escolha /retake ou /bd no chat.'
        }
        return
    }
    $chat = [regex]::Match($line, '" say(?:_team)? "(?<message>[^"\r\n]*)"')
    if (-not $chat.Success) { return }
    $choice = $chat.Groups['message'].Value.Trim().ToLowerInvariant()
    if ($choice -notin @('/retake','!retake','/bd','!bd')) { return }
    if (-not $owner) { $script:owner = $steam; Log "Primeiro jogador pelo chat: $steam" }
    if ($steam -ne $owner) {
        Broadcast 'Somente o primeiro jogador pode escolher o modo.'
        return
    }
    $newMode = if ($choice -match 'retake') { 'retake' } else { 'bd' }
    if ($newMode -eq $mode) {
        Broadcast "Modo $newMode ja esta ativo."
        return
    }
    $script:mode = $newMode
    Log "Modo escolhido: $newMode pelo jogador $steam"
    Broadcast "Modo $newMode escolhido. Carregando mapa..."
    if ($newMode -eq 'retake') {
        [void](Rcon 'game_type 0; game_mode 0; sv_skirmish_id 12; map de_mirage')
    } else {
        [void](Rcon 'game_type 0; game_mode 2; sv_skirmish_id 0; map de_inferno')
    }
}

try {
    Log 'Controlador iniciado na porta local 28015.'
    $nextRegister = [datetime]::MinValue
    $nextPoll = [datetime]::MinValue
    $pending = $listener.GetContextAsync()
    while ($true) {
        if ((Get-Date) -ge $nextRegister) {
            [void](Rcon 'log on')
            [void](Rcon 'logaddress_add_http "http://127.0.0.1:28015/"')
            $nextRegister = (Get-Date).AddMinutes(3)
        }
        if ((Get-Date) -ge $nextPoll) {
            $status = Rcon 'status'
            if ($status -match 'players\s*:\s*0 humans' -and $owner) {
                $owner = $null
                $mode = $null
                Log 'Servidor vazio; escolha liberada.'
            }
            $nextPoll = (Get-Date).AddSeconds(5)
        }
        if ($pending.Wait(500)) {
            $context = $pending.GetAwaiter().GetResult()
            $pending = $listener.GetContextAsync()
            try {
                $reader = [IO.StreamReader]::new($context.Request.InputStream, $context.Request.ContentEncoding)
                $body = $reader.ReadToEnd()
                $reader.Dispose()
                $context.Response.StatusCode = 200
                $context.Response.Close()
                foreach ($line in ($body -split '[\r\n]+')) { Handle-Line $line }
            } catch { Log "HTTP: $($_.Exception.Message)"; try { $context.Response.Close() } catch {} }
        }
    }
} finally { $listener.Stop(); $listener.Close() }
