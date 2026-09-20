Fix: espera sempre em terra, sem ponto seguro fixo.

Substituir:
- autofarm/region.luau
- autofarm/controller.luau
- autofarm/missions/water.luau

Comportamento:
- Nao existe ponto de espera salvo/fixo.
- Se a criatura ja estiver em terra, nao move.
- Se estiver na agua ao entrar em espera, procura o terreno seco mais proximo a partir da posicao atual.
- A busca fica no mesmo bioma.
- Depois de beber, sai da agua antes de continuar/aguardar.
- A espera por grupo, ataque, fome/sede ou recurso tambem garante terra seca.

O seekShelter de features/survival.luau nao foi alterado; ele continua sendo usado apenas para recuperacao/sobrevivencia.
