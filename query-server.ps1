param([string]$Command = 'css_plugins list')
$ErrorActionPreference = 'Stop'
$privateConfig = 'D:\CS2Server\game\game\csgo\cfg\server-private.cfg'
$line = Get-Content -LiteralPath $privateConfig | Where-Object { $_ -match '^rcon_password' } | Select-Object -First 1
if ($line -notmatch '"([^"]+)"') { throw 'Senha RCON local nao encontrada.' }
$password = $Matches[1]
$address = (Get-NetTCPConnection -LocalPort 27015 -State Listen | Select-Object -First 1).LocalAddress
$client = [Net.Sockets.TcpClient]::new()
$client.Connect($address, 27015)
$client.ReceiveTimeout = 5000
$stream = $client.GetStream()

function Send-Packet([int]$id, [int]$type, [string]$body) {
    $payload = [Text.Encoding]::UTF8.GetBytes($body)
    $writer = [IO.BinaryWriter]::new($stream, [Text.Encoding]::UTF8, $true)
    $writer.Write([int](10 + $payload.Length))
    $writer.Write($id)
    $writer.Write($type)
    $writer.Write($payload)
    $writer.Write([byte]0)
    $writer.Write([byte]0)
    $writer.Flush()
}
function Read-Packet {
    $reader = [IO.BinaryReader]::new($stream, [Text.Encoding]::UTF8, $true)
    $length = $reader.ReadInt32()
    if ($length -lt 10 -or $length -gt 1048576) { throw "Pacote RCON invalido: $length" }
    $id = $reader.ReadInt32()
    $type = $reader.ReadInt32()
    $body = $reader.ReadBytes($length - 10)
    [void]$reader.ReadBytes(2)
    return [pscustomobject]@{ Id = $id; Type = $type; Text = [Text.Encoding]::UTF8.GetString($body) }
}

try {
    Send-Packet 1 3 $password
    $authed = $false
    for ($i = 0; $i -lt 3; $i++) {
        $packet = Read-Packet
        if ($packet.Type -eq 2) {
            if ($packet.Id -ne 1) { throw 'Autenticacao RCON recusada.' }
            $authed = $true
            break
        }
    }
    if (-not $authed) { throw 'Servidor nao confirmou RCON.' }
    Send-Packet 2 2 $Command
    $response = Read-Packet
    Write-Output $response.Text
} finally {
    $client.Dispose()
}
