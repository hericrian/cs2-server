$server = Get-CimInstance Win32_Process | Where-Object {
    $_.Name -eq 'cs2.exe' -and $_.CommandLine -like '*-dedicated*'
}
if ($server) {
    $server | ForEach-Object { Stop-Process -Id $_.ProcessId; Write-Host "Servidor parado: PID $($_.ProcessId)" }
} else { Write-Host 'Servidor nao esta em execucao.' }
foreach ($name in @('mode-controller','chat-receiver')) {
    $pidFile = "D:\CS2Server\logs\$name.pid"
    if (Test-Path -LiteralPath $pidFile) {
        $helperPid = [int](Get-Content -LiteralPath $pidFile -Raw)
        # So encerra se o PID ainda for o script; apos reiniciar o PC ele pode ser de outro programa.
        $helper = Get-CimInstance Win32_Process -Filter "ProcessId = $helperPid" -ErrorAction SilentlyContinue
        if ($helper -and $helper.CommandLine -like "*$name.ps1*") {
            Stop-Process -Id $helperPid -Force -ErrorAction SilentlyContinue
            Write-Host "$name parado."
        }
        Remove-Item -LiteralPath $pidFile -Force
    }
}
