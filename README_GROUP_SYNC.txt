CreaturesOfSonaria - Group Sync

SUBSTITUIR:
- app.luau
- autofarm/controller.luau
- autofarm/missions/attack.luau
- ui/interface.luau

CRIAR NOVO:
- features/group_sync.luau

Nao precisa alterar main.luau, region.luau ou players.luau.

Comportamento novo:
- cada instancia ativa do autofarm registra a conta em CoS_Sync/<UserId>.json;
- somente contas no MESMO servidor Roblox (mesmo JobId) entram no grupo;
- o grupo calcula um unico bioma-alvo pela uniao das missoes pendentes;
- todas as contas vao para o mesmo bioma;
- uma conta que terminou suas missoes espera as outras no mesmo bioma;
- o grupo so muda quando nenhuma conta ainda precisa daquele bioma;
- uma emergencia de fome/sede vira prioridade do grupo inteiro;
- heartbeat atualiza o estado a cada 0,75 s; conta sem atualizar por 6 s e removida temporariamente;
- a missao de ataque usa automaticamente outra conta do grupo como alvo;
- o dropdown de ataque continua existindo apenas como override manual opcional.

Importante:
As contas precisam estar no mesmo servidor do Roblox para formar um grupo e conseguir atacar uma a outra.
