using CounterStrikeSharp.API;
using CounterStrikeSharp.API.Core;
using CounterStrikeSharp.API.Modules.Commands;

namespace ModeChooser;

public sealed class ModeChooser : BasePlugin
{
    public override string ModuleName => "Escolha de modo: Retake / Braco Direito";
    public override string ModuleVersion => "1.0.0";
    public override string ModuleAuthor => "Servidor local";

    private ulong? _owner;
    private string? _mode;

    public override void Load(bool hotReload)
    {
        AddCommand("css_retake", "Selecionar Retake", (player, _) => Choose(player, "retake"));
        AddCommand("css_bd", "Selecionar Braco Direito", (player, _) => Choose(player, "bd"));
        AddCommand("css_modo", "Mostrar o modo atual", (player, _) => ShowMode(player));
        RegisterListener<Listeners.OnClientPutInServer>(OnJoin);
        RegisterListener<Listeners.OnClientDisconnectPost>(_ => AddTimer(15, CheckEmpty));
        RegisterListener<Listeners.OnMapStart>(_ => AddTimer(3, ApplyCurrentMode));
        if (hotReload) AddTimer(2, () => {
            var first = Humans().FirstOrDefault();
            if (first != null) { _owner = first.SteamID; Prompt(first); }
        });
    }

    private static List<CCSPlayerController> Humans() => Utilities.GetPlayers()
        .Where(p => p.IsValid && !p.IsBot && !p.IsHLTV).ToList();

    private void OnJoin(int slot)
    {
        AddTimer(2, () => {
            var player = Utilities.GetPlayerFromSlot(slot);
            if (player == null || !player.IsValid || player.IsBot || player.IsHLTV) return;
            _owner ??= player.SteamID;
            Prompt(player);
        });
    }

    private void Prompt(CCSPlayerController player)
    {
        if (!player.IsValid) return;
        if (_owner == player.SteamID)
            player.PrintToChat(_mode == null
                ? "[Servidor] Voce foi o primeiro! Digite /retake ou /bd no chat para escolher o modo."
                : $"[Servidor] Modo: {_mode}. Voce pode trocar com /retake ou /bd.");
        else
            player.PrintToChat(_mode == null
                ? "[Servidor] Aguardando o primeiro jogador escolher /retake ou /bd."
                : $"[Servidor] Modo atual: {_mode}. Digite /modo para consultar.");
    }

    private void ShowMode(CCSPlayerController? player)
    {
        player?.PrintToChat(_mode == null
            ? "[Servidor] Aguardando escolha: /retake ou /bd."
            : $"[Servidor] Modo atual: {_mode}.");
    }

    private void Choose(CCSPlayerController? player, string mode)
    {
        if (player == null || !player.IsValid || player.IsBot) return;
        _owner ??= player.SteamID;
        if (_owner != player.SteamID)
        {
            player.PrintToChat("[Servidor] Somente o primeiro jogador pode escolher o modo.");
            return;
        }
        if (_mode == mode)
        {
            player.PrintToChat($"[Servidor] O modo {mode} ja esta ativo.");
            return;
        }
        _mode = mode;
        foreach (var human in Humans())
            human.PrintToChat($"[Servidor] Modo escolhido: {mode}. Carregando mapa...");
        if (mode == "bd")
        {
            Server.ExecuteCommand("retakes_enabled 0");
            Server.ExecuteCommand("game_type 0; game_mode 2; sv_skirmish_id 0");
            Server.ExecuteCommand("map de_inferno");
        }
        else
        {
            Server.ExecuteCommand("retakes_enabled 0");
            Server.ExecuteCommand("game_type 0; game_mode 0; sv_skirmish_id 0");
            Server.ExecuteCommand("map de_mirage");
        }
    }

    private void ApplyCurrentMode()
    {
        if (_mode == "retake") Server.ExecuteCommand("retakes_enabled 1");
        else if (_mode == "bd")
        {
            Server.ExecuteCommand("retakes_enabled 0");
            Server.ExecuteCommand("mp_warmup_pausetimer 0; mp_warmup_end");
        }
        else Server.ExecuteCommand("retakes_enabled 0");
    }

    private void CheckEmpty()
    {
        var humans = Humans();
        if (humans.Count == 0)
        {
            _owner = null;
            _mode = null;
            Server.ExecuteCommand("retakes_enabled 0");
        }
        else if (_owner.HasValue && humans.All(p => p.SteamID != _owner.Value))
        {
            _owner = humans[0].SteamID;
            Prompt(humans[0]);
        }
    }
}
