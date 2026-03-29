# Análise do erro "Meus Chats" no drawer da comunidade

## Problema identificado

O botão "Meus Chats" no `community_drawer.dart` navega para `/chats` (linha 486).

A rota `/chats` está dentro do `ShellRoute` (app_router.dart linha 119), que renderiza
`ChatListScreen` dentro do `ShellScreen` (com bottom navigation bar).

Quando o usuário está dentro de uma comunidade (`/community/:id`), ele está FORA do
ShellRoute. Ao fazer `context.push('/chats')`, o GoRouter tenta empurrar a rota `/chats`
que pertence ao ShellRoute. Isso causa um conflito porque:

1. A rota `/chats` está dentro de um `ShellRoute`, que exige o `ShellScreen` como wrapper
2. Ao usar `context.push('/chats')` de fora do shell, o GoRouter pode não conseguir
   resolver corretamente o shell parent, causando erro de renderização

## Solução

Trocar `context.push('/chats')` por `context.go('/chats')` para que o GoRouter faça
uma navegação completa (não push) para a rota dentro do ShellRoute, reconstruindo
a árvore de widgets corretamente com o ShellScreen.

Mesma correção deve ser aplicada ao item "Chats Públicos" que também usa `context.push('/chats')`.
