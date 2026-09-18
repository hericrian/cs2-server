$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$query = Join-Path $root 'query-server.ps1'
$events = 'D:\CS2Server\logs\chat-events.log'
$log = 'D:\CS2Server\logs\mode-controller.log'
$mapsDir = 'D:\CS2Server\game\game\csgo\maps'

# Dono do servidor: sempre admin.
$owners = @('[U:1:1178946286]')
# Primeiro jogador humano depois do servidor vazio: vira admin tambem.
$firstPlayer = $null
$mode = 'retake'

$modes = [ordered]@{
    'retake' = @{ Nome = 'Retake';               Alias = 'retakes';     Mapa = 'de_mirage' }
    'comp'   = @{ Nome = 'Competitivo';          Alias = 'competitive'; Mapa = 'de_mirage' }
    'casual' = @{ Nome = 'Casual';               Alias = 'casual';      Mapa = 'de_dust2'  }
    'bd'     = @{ Nome = 'Braco Direito';        Alias = 'wingman';     Mapa = 'de_inferno'}
    'dm'     = @{ Nome = 'Mata-mata';            Alias = 'deathmatch';  Mapa = 'de_dust2'  }
    'ar'     = @{ Nome = 'Corrida Armamentista'; Alias = 'armsrace';    Mapa = 'ar_shoots' }
    'demo'   = @{ Nome = 'Demolicao';            Tipo  = 1; Modo = 1;   Mapa = 'de_dust2'  }
    'treino' = @{ Nome = 'Treino de granada';    Alias = 'casual';      Mapa = 'de_mirage'; Exec = 'treino.cfg'
                  Avisos = @('Treino ligado: granada infinita, dinheiro cheio, respawn na hora.',
                             'No console: noclip para voar, sv_rethrow_last_grenade repete a granada.') }
    'gc'     = @{ Nome = 'Partida 5x5';          Alias = 'competitive'; Mapa = 'de_mirage'; Exec = 'gc_aquecimento.cfg'
                  Avisos = @('Aquecimento. Montem os times: 5 de cada lado.',
                             'Quando todos estiverem prontos, um admin digita /faca.') }
}
$dificuldades = @{ 'facil' = 0; 'normal' = 1; 'dificil' = 2; 'expert' = 3 }

# Estado da partida 5x5: '', 'aquecimento', 'faca', 'escolha', 'live'
$matchState = ''
$knifeWinner = $null
$votes = @{}
$voteEndsAt = $null
$pendingExec = $null
$pendingAvisos = @()

function Write-Log([string]$message) {
    Add-Content -LiteralPath $log -Value ("$(Get-Date -Format o) $message")
}
function Get-Maps {
    $lista = @{}
    foreach ($arquivo in Get-ChildItem -LiteralPath $mapsDir -Filter '*.vpk' -ErrorAction SilentlyContinue) {
        $nome = $arquivo.BaseName
        if ($nome -match '_vanity$|^workshop_preview|^graphics_settings$|^lobby_mapveto$|^warehouse') { continue }
        $lista[$nome] = $nome
        $curto = $nome -replace '^(de_|cs_|ar_)', ''
        if (-not $lista.ContainsKey($curto)) { $lista[$curto] = $nome }
    }
    return $lista
}
$maps = Get-Maps

function Rcon([string]$command, [int]$tentativas = 3) {
    for ($i = 1; $i -le $tentativas; $i++) {
        try { return (& $query $command 2>$null | Out-String).Trim() }
        catch {
            if ($i -eq $tentativas) { Write-Log "RCON falhou ($command): $($_.Exception.Message -replace '\s+', ' ')"; return $null }
            Start-Sleep -Milliseconds 700
        }
    }
}
function Say([string]$message) { [void](Rcon ('say ' + ($message -replace '"', "'")) 1) }

function Show-Menu {
    Say '--------- COMANDOS DO SERVIDOR ---------'
    Say 'PARTIDA 5x5: /gc mirage  ->  /faca  ->  voto /ficar ou /trocar'
    Say 'MODOS: /retake /comp /casual /bd /dm /ar /demo'
    Say 'TREINO DE PIXEL: /treino inferno'
    Say 'MAPAS: /mapa dust2   (lista: /mapas)'
    Say 'BOTS: /bots 5   /bots 0   /botparado 2   /dificuldade normal'
    Say 'OUTROS: /modo /reiniciar /ajuda'
    Say 'Mandam no servidor: o dono e o primeiro a entrar.'
    Say '---------------------------------------'
}
function Is-Admin([string]$steam) {
    return ($owners -contains $steam) -or ($firstPlayer -and $steam -eq $firstPlayer)
}
function Set-Mode([string]$chave, [string]$mapa) {
    $m = $modes[$chave]
    if (-not $mapa) { $mapa = $m.Mapa }
    $limpar = if ($m.Exec) { '' } else { 'sv_cheats 0; sv_infinite_ammo 0; mp_buy_anywhere 0; ' }
    if ($m.Alias) { $cmd = $limpar + "game_alias $($m.Alias); map $mapa" }
    else { $cmd = $limpar + "game_type $($m.Tipo); game_mode $($m.Modo); map $mapa" }
    Say "Modo $($m.Nome) em $mapa. Carregando..."
    [void](Rcon $cmd 2)
    $script:mode = $chave
    $script:pendingExec = $m.Exec
    $script:pendingAvisos = if ($m.Avisos) { $m.Avisos } else { @() }
    $script:matchState = if ($chave -eq 'gc') { 'aquecimento' } else { '' }
    $script:knifeWinner = $null
    $script:votes = @{}
    $script:voteEndsAt = $null
    Write-Log "Modo $chave em $mapa"
}
function Start-Live {
    [void](Rcon 'exec gc_live.cfg' 2)
    Say '>>> VALENDO! MR12, prorrogacao ligada ate sair vencedor. <<<'
    $script:matchState = 'live'
    $script:votes = @{}
    $script:voteEndsAt = $null
    Write-Log 'Partida live.'
}
function Close-Vote {
    $ficar = @($votes.Values | Where-Object { $_ -eq 'ficar' }).Count
    $trocar = @($votes.Values | Where-Object { $_ -eq 'trocar' }).Count
    Say "Votos: ficar $ficar x $trocar trocar."
    if ($trocar -gt $ficar) {
        [void](Rcon 'mp_swapteams' 2)
        Say 'Times trocados de lado.'
    } else {
        Say 'Cada time fica onde esta.'
    }
    Start-Sleep -Seconds 2
    Start-Live
}

Write-Log 'Controlador iniciado.'
$seen = if (Test-Path -LiteralPath $events) { @(Get-Content -LiteralPath $events).Count } else { 0 }
$registered = $false
$nextPoll = [datetime]::MinValue

while ($true) {
    if (-not $registered) {
        $status = Rcon 'status' 1
        if ($status -match 'players\s*:') {
            [void](Rcon 'log on' 1)
            [void](Rcon 'logaddress_add_http "http://127.0.0.1:28015/"' 1)
            $registered = $true
            Write-Log 'Logs HTTP registrados.'
        }
    }
    if ($pendingExec) {
        $status = Rcon 'status' 1
        if ($status -match 'players\s*:') {
            [void](Rcon "exec $pendingExec" 2)
            foreach ($aviso in $pendingAvisos) { Say $aviso }
            Write-Log "Exec $pendingExec"
            $pendingExec = $null
            $pendingAvisos = @()
        }
    }
    if ($voteEndsAt -and (Get-Date) -ge $voteEndsAt) { $voteEndsAt = $null; Close-Vote }
    if ((Get-Date) -ge $nextPoll) {
        $status = Rcon 'status' 1
        if ($status -match 'players\s*:\s*0 humans' -and $firstPlayer) {
            $firstPlayer = $null
            Write-Log 'Servidor vazio; primeiro jogador liberado.'
        }
        $nextPoll = (Get-Date).AddSeconds(15)
    }

    if (Test-Path -LiteralPath $events) {
        $lines = @(Get-Content -LiteralPath $events)
        if ($lines.Count -lt $seen) { $seen = 0 }
        while ($seen -lt $lines.Count) {
            $line = $lines[$seen]
            $seen++

            # Fim do round de faca: define quem escolhe o lado.
            if ($matchState -eq 'faca' -and $line -match 'Team "(?<time>CT|TERRORIST)" triggered "SFUI_Notice_(?<tipo>[A-Za-z_]+)"') {
                $vencedor = $Matches['time']
                if ($Matches['tipo'] -match 'Draw') {
                    Say 'Empate na faca. Refazendo o round.'
                    [void](Rcon 'mp_restartgame 1' 2)
                    continue
                }
                $knifeWinner = $vencedor
                $matchState = 'escolha'
                $votes = @{}
                $voteEndsAt = (Get-Date).AddSeconds(30)
                [void](Rcon 'mp_warmup_start; mp_warmup_pausetimer 1' 2)
                $nomeTime = if ($vencedor -eq 'CT') { 'CT' } else { 'TR' }
                Say "$nomeTime ganhou a faca! Time $nomeTime vota agora: /ficar ou /trocar"
                Say 'Vale o que a maioria do time vencedor votar. 30 segundos.'
                Write-Log "Faca vencida por $vencedor"
                continue
            }

            $identity = [regex]::Match($line, '"(?<nome>[^"\r\n]*)<\d+><(?<steam>\[U:1:\d+\]|STEAM_\d+:\d+:\d+|7656119\d+)><(?<time>[^>]*)>"')
            if (-not $identity.Success) { continue }
            $steam = $identity.Groups['steam'].Value
            $nome = $identity.Groups['nome'].Value
            $time = $identity.Groups['time'].Value

            if ($line -match '" (entered the game|connected)') {
                if (-not $firstPlayer -and -not ($owners -contains $steam)) {
                    $firstPlayer = $steam
                    Write-Log "Primeiro jogador: $nome $steam"
                }
                Say "$nome entrou. Servidor do voltz - Instagram @hericrian"
                Say 'Digite /ajuda para ver os comandos.'
                continue
            }

            $chat = [regex]::Match($line, '" say(?:_team)? "(?<message>[^"\r\n]*)"')
            if (-not $chat.Success) { continue }
            $texto = $chat.Groups['message'].Value.Trim()
            if ($texto -notmatch '^[/!]') { continue }
            $partes = $texto.TrimStart('/', '!').Trim() -split '\s+'
            $cmd = $partes[0].ToLowerInvariant()
            $arg = if ($partes.Count -gt 1) { $partes[1].ToLowerInvariant() } else { $null }

            # Voto do time que ganhou a faca.
            if ($matchState -eq 'escolha' -and $cmd -in @('ficar', 'trocar')) {
                if ($time -ne $knifeWinner) { Say "$nome, so o time que ganhou a faca vota."; continue }
                $votes[$steam] = $cmd
                Say "$nome votou em $cmd."
                continue
            }

            if ($cmd -in @('ajuda', 'menu', 'comandos', 'help')) { Show-Menu; continue }
            if ($cmd -eq 'modo') { Say "Modo atual: $($modes[$mode].Nome)"; continue }
            if ($cmd -eq 'mapas') {
                $de = ($maps.Keys | Where-Object { $maps[$_] -like 'de_*' -and $_ -notlike 'de_*' } | Sort-Object) -join ' '
                Say "Mapas: $de"
                Say 'Outros: italy office shelter baggage shoots pool_day'
                continue
            }

            $comandosAdmin = @('retake', 'comp', 'casual', 'bd', 'dm', 'ar', 'demo', 'treino', 'gc',
                               'faca', 'live', 'mapa', 'map', 'bots', 'bot', 'botparado', 'dificuldade',
                               'reiniciar', 'restart')
            if ($cmd -notin $comandosAdmin) { continue }
            if (-not (Is-Admin $steam)) {
                Say "$nome, so o dono e o primeiro jogador podem usar esse comando."
                continue
            }

            switch ($cmd) {
                { $modes.Contains($_) } {
                    $mapa = $null
                    if ($arg -and $maps.ContainsKey($arg)) { $mapa = $maps[$arg] }
                    elseif ($arg) { Say "Mapa '$arg' nao existe. Veja /mapas."; break }
                    Set-Mode $cmd $mapa
                    break
                }
                'faca' {
                    [void](Rcon 'exec gc_faca.cfg' 2)
                    $script:matchState = 'faca'
                    Say '>>> ROUND DE FACA! Quem ganhar escolhe o lado. <<<'
                    Write-Log 'Round de faca iniciado.'
                    break
                }
                'live' {
                    Start-Live
                    break
                }
                { $_ -in @('mapa', 'map') } {
                    if (-not $arg) { Say 'Use assim: /mapa dust2'; break }
                    if (-not $maps.ContainsKey($arg)) { Say "Mapa '$arg' nao existe. Veja /mapas."; break }
                    Say "Trocando para $($maps[$arg])..."
                    [void](Rcon "map $($maps[$arg])" 2)
                    Write-Log "Mapa $($maps[$arg]) por $nome"
                    break
                }
                { $_ -in @('bots', 'bot') } {
                    if ($arg -notmatch '^\d+$') { Say 'Use assim: /bots 5   (ou /bots 0 para tirar todos)'; break }
                    $quantidade = [Math]::Min([int]$arg, 10)
                    if ($quantidade -eq 0) {
                        [void](Rcon 'bot_quota 0; bot_kick' 2)
                        Say 'Bots removidos.'
                    } else {
                        [void](Rcon "bot_stop 0; bot_dont_shoot 0; bot_quota_mode fill; bot_quota $quantidade" 2)
                        Say "Agora sao $quantidade jogadores com bots."
                    }
                    Write-Log "Bots $quantidade por $nome"
                    break
                }
                'botparado' {
                    $quantidade = if ($arg -match '^\d+$') { [Math]::Min([int]$arg, 10) } else { 1 }
                    [void](Rcon "bot_stop 1; bot_dont_shoot 1; bot_difficulty 0; bot_quota_mode fill; bot_quota $quantidade" 2)
                    Say "$quantidade bot(s) parado(s) para treino. /bots 0 tira todos."
                    Write-Log "Bots parados: $quantidade por $nome"
                    break
                }
                'dificuldade' {
                    if (-not $arg -or -not $dificuldades.ContainsKey($arg)) { Say 'Use: /dificuldade facil, normal, dificil ou expert'; break }
                    [void](Rcon "bot_difficulty $($dificuldades[$arg])" 2)
                    Say "Dificuldade dos bots: $arg."
                    Write-Log "Dificuldade $arg por $nome"
                    break
                }
                { $_ -in @('reiniciar', 'restart') } {
                    [void](Rcon 'mp_restartgame 1' 2)
                    Say 'Reiniciando a partida...'
                    break
                }
            }
        }
    }
    Start-Sleep -Seconds 2
}
