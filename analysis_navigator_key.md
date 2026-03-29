# Análise do erro: '!keyReservation.contains(key)' is not true

## Erro
```
'package:flutter/src/widgets/navigator.dart': Failed assertion: line 4046 pos 18:
'!keyReservation.contains(key)': is not true.
```

## Causa raiz
O erro `!keyReservation.contains(key)` ocorre quando o Flutter Navigator tenta
registrar uma rota com uma key que já está reservada. Isso acontece quando:

1. `Navigator.pop(context)` é chamado para fechar o drawer
2. Imediatamente após, `context.go('/chats')` ou `context.push(...)` é chamado
3. O pop e o push/go acontecem no mesmo frame, causando conflito de keys no Navigator

O `Navigator.pop(context)` fecha o drawer (que é uma rota overlay no Navigator),
mas quando `context.go()` é chamado sincronamente logo depois, o GoRouter tenta
manipular o Navigator antes que o pop tenha sido completamente processado.

## Solução
Usar `WidgetsBinding.instance.addPostFrameCallback` para atrasar a navegação
até o próximo frame, garantindo que o drawer já foi completamente fechado.

Ou alternativamente, fechar o drawer primeiro e usar um pequeno delay antes
de navegar. A abordagem mais limpa é usar `addPostFrameCallback`.
