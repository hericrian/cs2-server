$ErrorActionPreference = 'Stop'
# Tunel do servidor de casa ate a maquina da Oracle em Sao Paulo.
# O CS2 fica acessivel em 147.15.45.159:27015 sem precisar de IP publico aqui.
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$exe = Join-Path $root 'frp\frp_0.71.0_windows_amd64\frpc.exe'
$cfg = Join-Path $root 'frp\frpc.toml'
if (-not (Test-Path -LiteralPath $exe)) { throw "frpc nao encontrado em $exe" }
& $exe -c $cfg
