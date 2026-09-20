FIX - autofarm por bioma + remover ShoomPiles do autofarm

Substituir:
- autofarm/region.luau
- autofarm/controller.luau
- features/group_sync.luau

Mudancas:
1. ShoomPilesCollected nao conta mais como missao do autofarm.
2. O autofarm nao carrega nem executa shoom_piles_mission.luau.
3. O botao manual "Coletar ShoomPiles" continua separado e nao foi removido.
4. O grupo mantem o mesmo bioma enquanto qualquer conta ainda tiver uma das 6 missoes normais pendentes:
   - Sniff
   - ConcealScent
   - EatFoodDrinkWater
   - DistanceTravelled
   - TimePlayed
   - AttackOrHealCreatureOrNPC
5. Uma conta que terminar primeiro espera a outra no mesmo bioma.
6. So depois de ambas terminarem o bioma o grupo escolhe o proximo.
7. No primeiro ciclo, o grupo usa um bioma atual comum/deterministico para evitar alvos diferentes entre instancias.

Verificacao Real:
- autofarm/region.luau: 0 erros, 0 warnings
- autofarm/controller.luau: 0 erros, 0 warnings
- features/group_sync.luau: 0 erros, 0 warnings
