# Servidor CS2 em casa

Jogo instalado em `D:\CS2Server\game` (SteamCMD). Scripts nesta pasta (`D:\CS2Server\scripts`).
Logs em `D:\CS2Server\logs`.

## Uso

- `Iniciar servidor.cmd` liga o servidor e os dois auxiliares.
- `Parar servidor.cmd` para tudo.
- `Ver status.cmd` mostra se esta no ar.
- `Configurar token.cmd` grava um novo codigo de sessao (GSLT) e reinicia o servidor.

O servidor nao sobe sozinho, e de proposito. Para ligar, use o atalho
**Rodar server CS2** na Area de Trabalho, que chama `rodar-server-cs2.ps1`:
confere o tunel WireGuard, liga o playit como reserva, sobe o servidor e os
auxiliares, espera o mapa carregar e mostra os enderecos para mandar aos amigos.
O tunel do WireGuard e servico automatico e sobe junto com o Windows.

## Como conectar

No CS2, ative o console em Configuracoes > Jogo e digite:

- Na mesma rede de casa: `connect 192.168.0.6:27015` (o IP vem do DHCP e pode mudar;
  o `Iniciar servidor.cmd` mostra o atual)
- Amigos e PC da faculdade: `connect 147.15.45.159:27015` (rele em Sao Paulo, sem
  instalar nada do lado de quem entra)
- Alternativa: `connect 26.134.21.0:27015` pelo Radmin VPN

O provedor usa CGNAT e nao ha IPv6, entao liberar a porta no roteador nao funciona.
A saida foi uma maquina gratuita da Oracle em Sao Paulo (`cs2-relay-sp`, 147.15.45.159)
que recebe o trafego e entrega aqui por um tunel WireGuard.

## Rele em Sao Paulo

- Maquina Oracle Always Free (VM.Standard.E2.1.Micro, Oracle Linux 9), regiao Sao Paulo.
- Acesso: `ssh -i D:\CS2Server\scripts\ssh\oracle_cs2 opc@147.15.45.159`.
- Na maquina: WireGuard em 10.8.0.1 (porta 51820) e redirecionamento de UDP 27015
  para 10.8.0.2, que e este PC. Mascaramento ligado nas duas zonas do firewalld,
  senao a resposta do CS2 volta por fora e o jogador nao conecta.
- Neste PC: tunel `cs2-relay` no WireGuard, instalado como servico automatico.
  Se ele estiver parado, o endereco de Sao Paulo para de funcionar.
- O tunel carrega so a faixa 10.8.0.0/24, entao sua navegacao normal nao passa por la.
- Medido em 18/09/2026: 40 ms pelo rele, contra 230 ms pelo playit gratuito.
- O playit continua configurado como reserva (`expressing-ghz.tun.ply.gg:22052`),
  mas so funciona com o agente playit aberto.

## Comandos no chat do jogo

Quem pode usar: o dono (SteamID fixo em `mode-controller.ps1`) e o primeiro jogador
que entra depois do servidor ficar vazio.

| Comando | O que faz |
| --- | --- |
| `/ajuda` | mostra o menu no chat |
| `/retake` `/comp` `/casual` `/bd` `/dm` `/ar` `/demo` | troca de modo (aceita mapa junto: `/retake dust2`) |
| `/treino inferno` | treino de granada: infinitas, dinheiro cheio, respawn na hora |
| `/mapa dust2` / `/mapas` | troca de mapa / lista os mapas |
| `/bots 5` / `/bots 0` | bots preenchendo o servidor / remove todos |
| `/botparado 2` | bots parados que nao atiram, para treino |
| `/dificuldade facil\|normal\|dificil\|expert` | dificuldade dos bots |
| `/modo` `/reiniciar` | modo atual / reinicia a partida |

### Partida 5x5 no estilo campeonato

1. `/gc mirage` carrega o competitivo e deixa o servidor em aquecimento parado
   (`gc_aquecimento.cfg`: dinheiro cheio, granada infinita, sem bots).
2. Com os times montados, um admin digita `/faca`. Sai `gc_faca.cfg`: so faca,
   sem dinheiro, sem bomba.
3. O controlador le o fim do round no log (`Team "X" triggered "SFUI_Notice_..."`),
   segura o servidor em aquecimento e abre 30 segundos de votacao. So quem esta no
   time que ganhou a faca pode votar `/ficar` ou `/trocar`; vale a maioria.
4. Depois do voto entra `gc_live.cfg`: MR12 (24 rounds), troca de lado no meio,
   prorrogacao MR3 ligada. Empatou a prorrogacao, joga outra, ate sair vencedor.
   `/live` forca o inicio sem votacao.

Modos e os codigos do CS2 usados: retake (`game_alias retakes`, type 0 mode 5),
competitivo (0/1), casual (0/0), braco direito (0/2), mata-mata (1/2),
corrida armamentista (1/0) e demolicao (1/1).

## Escolha de modo pelo chat

`mode-controller.ps1` le o chat pelos logs HTTP (`chat-receiver.ps1`, porta local 28015)
e troca o modo por RCON (`query-server.ps1`). O primeiro jogador a entrar escolhe com
`/retake` ou `/bd`; quando o servidor fica vazio, a escolha e liberada de novo.

O retake e nativo do CS2 (`gamemode_retakecasual.cfg`), entao nao precisa de plugin.
Metamod e CounterStrikeSharp continuam desativados em `gameinfo.gi` porque travavam o
servidor; os arquivos ficaram em `D:\CS2Server\game\game\csgo\addons` e o projeto do
plugin em `ModeChooser`, para uma tentativa futura (texto no mapa, chat colorido).

## Cuidados aprendidos

- `sv_minrate 786432` derrubou o servidor na hora (18/09/2026). Nao usar.
- A maquina da Oracle so tem ~500 MB de RAM uteis. Qualquer tarefa pesada nela
  (atualizacao de indice do dnf, agente da Oracle) trava o sistema e o ping do rele
  sobe de 40 ms para mais de 250 ms. Por isso ficaram desligados: `dnf-makecache.timer`
  (mascarado), `oracle-cloud-agent`, `oracle-cloud-agent-updater` e `frps`.
  O perfil do `tuned` esta em `network-latency`.
- Para instalar algo na maquina, baixar o RPM direto pelo indice do repositorio em vez
  de usar `dnf install`, que consome memoria demais.

## Desempenho

O servidor sobe com prioridade alta e com console de verdade (janela minimizada).
Sem isso o CS2 escrevia cerca de 60 linhas de erro por segundo no log, o que provocava
travadas de quadro e o aviso vermelho de latencia no jogo.

## Configuracao

- `server.cfg` (copia usada pelo jogo em `D:\CS2Server\game\game\csgo\cfg\server.cfg`).
- `server-private.cfg`, so no jogo, guarda `rcon_password` e `sv_setsteamaccount`.
  Nao versionar nem compartilhar esse arquivo.

## Atualizacao

Quando o CS2 atualizar, o servidor precisa ser atualizado com o SteamCMD, senao os
jogadores nao conseguem entrar:

    D:\CS2Server\steamcmd\steamcmd.exe +force_install_dir D:\CS2Server\game +login anonymous +app_update 730 validate +quit
