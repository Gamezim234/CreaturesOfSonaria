Patch: ShoomPile + Mud sem foco

SUBSTITUIR:
- features/actions.luau
- autofarm/missions/mud.luau
- autofarm/missions/shoom_piles_mission.luau

Mud:
- deixa de usar apenas CurrentCharacter:Roll("Mud")
- usa a acao interna "Hide Scent" do ProximityMenu
- essa acao executa a rolagem e a confirmacao usada pelo jogo para ConcealScent

ShoomPile:
- deixa de usar keypress/keyrelease da tecla E
- usa a acao interna "Collect" do ProximityMenu
- portanto nao depende do foco da janela

Os 3 arquivos passaram no checker do Real com 0 erros e 0 warnings.
