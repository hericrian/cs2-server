$server = Get-CimInstance Win32_Process | Where-Object {
    $_.Name -eq 'cs2.exe' -and $_.CommandLine -like '*-dedicated*'
}
if ($server) { $server | Select-Object ProcessId,CommandLine | Format-List }
else { Write-Host 'Servidor nao esta em execucao.' }
Get-NetUDPEndpoint -LocalPort 27015 -ErrorAction SilentlyContinue | Select-Object LocalAddress,LocalPort,OwningProcess
Get-ChildItem 'D:\CS2Server\logs' -File -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 2 FullName,Length,LastWriteTime
foreach ($name in @('chat-receiver','mode-controller')) {
    $pidFile = "D:\CS2Server\logs\$name.pid"
    if (Test-Path -LiteralPath $pidFile) {
        $helperPid = [int](Get-Content -LiteralPath $pidFile -Raw)
        $process = Get-Process -Id $helperPid -ErrorAction SilentlyContinue
        Write-Host "$name`: $(if ($process) { "rodando (PID $helperPid)" } else { 'parado' })"
    }
}
Get-Content 'D:\CS2Server\logs\mode-controller.log' -Tail 5 -ErrorAction SilentlyContinue
