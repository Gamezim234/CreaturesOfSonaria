CreaturesOfSonaria - survival + mud + attack fix

SUBSTITUIR:
- features/group_sync.luau
- features/actions.luau
- autofarm/controller.luau
- autofarm/missions/water.luau
- autofarm/missions/food.luau
- autofarm/missions/mud.luau
- autofarm/missions/attack.luau

Mudancas:
1) Fome/sede
- nao muda mais o bioma do grupo
- abaixo de 10% vira prioridade local de sobrevivencia
- se EatFoodDrinkWater estiver pendente, escolhe comida ou agua pela menor porcentagem
- para de comer/beber assim que a missao EatFoodDrinkWater completar
- se a missao ja estiver completa, so come/bebe por sobrevivencia

2) Lama
- procura o wrapper interno do Mud
- chama a acao Hide Scent correta

3) Ataque
- group_sync agora publica posicao e tamanho da Root
- ataque usa a posicao compartilhada da outra conta
- nao depende mais de PlayerWrapper.getCharacterFromPlayer(), que estava retornando nil

Nao precisa alterar app.luau, region.luau ou main.luau.
