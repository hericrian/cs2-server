$ErrorActionPreference = 'Stop'
$events = 'D:\CS2Server\logs\chat-events.log'
$listener = [Net.HttpListener]::new()
$listener.Prefixes.Add('http://127.0.0.1:28015/')
$listener.Start()
try {
    while ($true) {
        $context = $listener.GetContext()
        try {
            $reader = [IO.StreamReader]::new($context.Request.InputStream, $context.Request.ContentEncoding)
            $body = $reader.ReadToEnd()
            $reader.Dispose()
            $context.Response.StatusCode = 200
            $context.Response.Close()
            foreach ($line in ($body -split '[\r\n]+')) {
                if ($line -match 'entered the game|connected|disconnected|" say(?:_team)? "|triggered "SFUI_Notice|World triggered') {
                    Add-Content -LiteralPath $events -Value $line
                }
            }
        } catch { try { $context.Response.Close() } catch {} }
    }
} finally { $listener.Stop(); $listener.Close() }
