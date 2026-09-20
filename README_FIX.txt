CreaturesOfSonaria - review fixes

Substitua estes arquivos no GitHub:
- features/actions.luau
- features/group_sync.luau
- features/survival.luau
- autofarm/missions/attack.luau
- autofarm/missions/walk.luau

Correcoes:
- setLaying agora usa ClientCharacter:Lay(), sem keypress/foco.
- estado de deitar e resetado quando o personagem muda/respawna.
- ataque agora e fail-closed: sem HP, dano, lifeId, idade ou sync valido, nao morde.
- alvo e rechecado novamente imediatamente antes da mordida.
- restart do slot so continua quando RestartSlotRemote retorna sucesso.
- ausencia temporaria de personagem/slot nao e tratada automaticamente como morte.
- requires dinamicos de Sonar/SaveSelectionClient foram ajustados para o checker do Real.
- tornado nao usa mais spam de Attack; usa o estado interno de fling e tenta abrigo.
- DistanceTravelled nao teleporta 120 studs para cima quando nao encontra ponto valido.
- DistanceTravelled so retorna sucesso quando houve progresso real.

Validacao no Real:
- features/actions.luau: 0 erros, 0 warnings
- features/group_sync.luau: 0 erros, 0 warnings
- features/survival.luau: 0 erros, 0 warnings
- autofarm/missions/attack.luau: 0 erros, 0 warnings
- autofarm/missions/walk.luau: 0 erros, 0 warnings
