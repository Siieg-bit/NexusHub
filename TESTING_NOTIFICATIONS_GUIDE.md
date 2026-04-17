# Guia de Testes Manuais - Notificações Push

## Pré-requisitos

1. **Firebase Cloud Messaging (FCM)**
   - Service Account JSON configurado em Supabase Secrets
   - `FCM_SERVICE_ACCOUNT_JSON` adicionado

2. **Aplicação**
   - App Flutter compilado e instalado no dispositivo
   - Permissões de notificação concedidas
   - FCM token salvo em `profiles.fcm_token`

3. **Ambiente**
   - Supabase backend rodando
   - Edge Functions ativas
   - Database com dados de teste

## Cenários de Teste

### 1. Notificações Globais

#### 1.1 Like em Post Global
**Passos:**
1. Usuário A faz login
2. Usuário B faz login em outro dispositivo
3. Usuário B dá like em um post de Usuário A
4. Verificar notificação em Usuário A

**Verificações:**
- [ ] Notificação aparece no celular
- [ ] Título: "Novo like"
- [ ] Corpo: Nome de Usuário B + "curtiu seu post"
- [ ] Avatar: Avatar global de Usuário B
- [ ] Nickname: Nickname global de Usuário B
- [ ] Clique navega para o post

#### 1.2 Comentário em Post Global
**Passos:**
1. Usuário A faz login
2. Usuário B comenta em um post de Usuário A
3. Verificar notificação em Usuário A

**Verificações:**
- [ ] Notificação aparece
- [ ] Tipo: "comment"
- [ ] Avatar com ícone de comentário
- [ ] Clique navega para o post/comentário

#### 1.3 Follow
**Passos:**
1. Usuário A faz login
2. Usuário B segue Usuário A
3. Verificar notificação em Usuário A

**Verificações:**
- [ ] Notificação aparece
- [ ] Tipo: "follow"
- [ ] Avatar com ícone de pessoa+
- [ ] Clique navega para perfil de Usuário B

### 2. Notificações de Comunidade

#### 2.1 Like em Post da Comunidade
**Passos:**
1. Usuário A entra em uma comunidade
2. Define um nickname local: "Mestre Local"
3. Define um avatar local
4. Usuário B dá like em post de Usuário A na comunidade
5. Verificar notificação em Usuário A

**Verificações:**
- [ ] Notificação aparece
- [ ] **Avatar: Avatar LOCAL de Usuário A** (não global)
- [ ] **Nickname: "Mestre Local"** (não nickname global)
- [ ] Clique navega para o post

#### 2.2 Comentário em Post da Comunidade
**Passos:**
1. Usuário A tem perfil local na comunidade
2. Usuário B comenta em post de Usuário A
3. Verificar notificação em Usuário A

**Verificações:**
- [ ] Avatar: Avatar local
- [ ] Nickname: Nickname local
- [ ] Tipo: "comment"
- [ ] Clique navega para post/comentário

#### 2.3 Convite para Comunidade
**Passos:**
1. Usuário A convida Usuário B para uma comunidade
2. Verificar notificação em Usuário B

**Verificações:**
- [ ] Notificação aparece
- [ ] Tipo: "community_invite"
- [ ] Botão "Aceitar" disponível
- [ ] Clique em "Aceitar" adiciona à comunidade

#### 2.4 Mudança de Role
**Passos:**
1. Usuário A é promovido a Leader em uma comunidade
2. Verificar notificação em Usuário A

**Verificações:**
- [ ] Notificação aparece
- [ ] Tipo: "role_change"
- [ ] Corpo indica nova role: "Você foi promovido a Leader"

### 3. Notificações de Chat

#### 3.1 Mensagem Direta
**Passos:**
1. Usuário A faz login
2. Usuário B envia mensagem direta para Usuário A
3. Verificar notificação em Usuário A

**Verificações:**
- [ ] Notificação aparece
- [ ] Canal: "nexushub_chat" (prioridade alta)
- [ ] Som e vibração
- [ ] Clique abre conversa

#### 3.2 Menção em Chat
**Passos:**
1. Usuário A está em um chat de grupo
2. Usuário B menciona Usuário A (@Usuário A)
3. Verificar notificação em Usuário A

**Verificações:**
- [ ] Notificação aparece
- [ ] Tipo: "chat_mention"
- [ ] Prioridade: Alta
- [ ] Clique abre chat

### 4. Notificações de Moderação

#### 4.1 Strike
**Passos:**
1. Usuário A recebe um strike
2. Verificar notificação em Usuário A

**Verificações:**
- [ ] Notificação aparece
- [ ] Tipo: "strike"
- [ ] Canal: "nexushub_moderation" (prioridade alta)
- [ ] Corpo: Motivo do strike
- [ ] Requer interação (não desaparece automaticamente)

#### 4.2 Ban
**Passos:**
1. Usuário A é banido de uma comunidade
2. Verificar notificação em Usuário A

**Verificações:**
- [ ] Notificação aparece
- [ ] Tipo: "ban"
- [ ] Prioridade: Alta
- [ ] Requer interação

### 5. Badges e Contagem

#### 5.1 Badge Atualiza com Não Lidas
**Passos:**
1. Usuário tem 0 notificações não lidas
2. Recebe 3 notificações
3. Verificar badge no ícone do app

**Verificações:**
- [ ] Badge mostra "3"
- [ ] Badge atualiza em tempo real
- [ ] Badge sincroniza com Supabase

#### 5.2 Badge Limpa ao Abrir
**Passos:**
1. Usuário tem 5 notificações não lidas
2. Abre a tela de notificações
3. Marca todas como lidas
4. Verificar badge

**Verificações:**
- [ ] Badge desaparece
- [ ] Badge volta a "0"
- [ ] Sincroniza com Supabase

#### 5.3 Badge por Categoria
**Passos:**
1. Usuário tem:
   - 2 notificações de chat não lidas
   - 3 notificações sociais não lidas
   - 1 notificação de comunidade não lida
2. Verificar contagem por categoria

**Verificações:**
- [ ] Chat: 2
- [ ] Social: 3
- [ ] Community: 1
- [ ] Total: 6

### 6. Estados do App

#### 6.1 Foreground (App Aberto)
**Passos:**
1. App está aberto
2. Recebe notificação
3. Verificar exibição

**Verificações:**
- [ ] Notificação local aparece
- [ ] Som toca
- [ ] Vibração funciona
- [ ] Pode clicar para navegar

#### 6.2 Background (App Minimizado)
**Passos:**
1. App está minimizado
2. Recebe notificação
3. Verificar exibição

**Verificações:**
- [ ] Notificação aparece na bandeja
- [ ] Som toca
- [ ] Vibração funciona
- [ ] Clique abre app e navega

#### 6.3 Terminated (App Fechado)
**Passos:**
1. App está completamente fechado
2. Recebe notificação
3. Verificar exibição

**Verificações:**
- [ ] Notificação aparece na bandeja
- [ ] Som toca
- [ ] Vibração funciona
- [ ] Clique abre app e navega para contexto

### 7. Perfil Local vs Global

#### 7.1 Verificar Exibição Correta
**Passos:**
1. Usuário A tem:
   - Nickname global: "João Silva"
   - Avatar global: avatar1.jpg
   - Nickname local (comunidade): "Mestre"
   - Avatar local: avatar-local.jpg
2. Recebe notificação de comunidade
3. Verificar qual perfil é exibido

**Verificações:**
- [ ] Nickname exibido: "Mestre" (local)
- [ ] Avatar exibido: avatar-local.jpg (local)
- [ ] NÃO exibe: "João Silva" ou avatar1.jpg

#### 7.2 Fallback para Global
**Passos:**
1. Usuário A tem:
   - Nickname global: "João Silva"
   - Avatar global: avatar1.jpg
   - Sem perfil local na comunidade
2. Recebe notificação de comunidade
3. Verificar qual perfil é exibido

**Verificações:**
- [ ] Nickname exibido: "João Silva" (global)
- [ ] Avatar exibido: avatar1.jpg (global)

### 8. Deep Linking

#### 8.1 Link para Post
**Passos:**
1. Recebe notificação de like em post
2. Clica na notificação
3. Verificar navegação

**Verificações:**
- [ ] App abre
- [ ] Navega para o post correto
- [ ] Post é exibido

#### 8.2 Link para Comunidade
**Passos:**
1. Recebe convite para comunidade
2. Clica na notificação
3. Verificar navegação

**Verificações:**
- [ ] App abre
- [ ] Navega para comunidade
- [ ] Comunidade é exibida

#### 8.3 Link para Perfil
**Passos:**
1. Recebe notificação de follow
2. Clica na notificação
3. Verificar navegação

**Verificações:**
- [ ] App abre
- [ ] Navega para perfil do usuário
- [ ] Perfil é exibido

## Checklist de Testes

### Antes de Começar
- [ ] Firebase Cloud Messaging configurado
- [ ] Supabase Secrets com FCM_SERVICE_ACCOUNT_JSON
- [ ] App compilado e instalado
- [ ] Permissões de notificação concedidas
- [ ] Dados de teste criados

### Testes Globais
- [ ] Like em post global
- [ ] Comentário em post global
- [ ] Follow
- [ ] Menção em post global

### Testes de Comunidade
- [ ] Like em post da comunidade (perfil local)
- [ ] Comentário em post da comunidade (perfil local)
- [ ] Convite para comunidade
- [ ] Mudança de role

### Testes de Chat
- [ ] Mensagem direta
- [ ] Menção em chat

### Testes de Moderação
- [ ] Strike
- [ ] Ban

### Testes de Badges
- [ ] Badge atualiza com não lidas
- [ ] Badge limpa ao abrir
- [ ] Badge por categoria

### Testes de Estados
- [ ] Foreground
- [ ] Background
- [ ] Terminated

### Testes de Perfil
- [ ] Perfil local exibido corretamente
- [ ] Fallback para global
- [ ] Avatar local exibido
- [ ] Nickname local exibido

### Testes de Deep Linking
- [ ] Link para post
- [ ] Link para comunidade
- [ ] Link para perfil

## Troubleshooting

### Notificações não aparecem
1. Verificar se FCM token está em `profiles.fcm_token`
2. Verificar logs da Edge Function em Supabase
3. Verificar se permissões foram concedidas
4. Verificar se `FCM_SERVICE_ACCOUNT_JSON` está configurado

### Perfil errado exibido
1. Verificar se `community_members` tem dados preenchidos
2. Verificar se `local_nickname` e `local_icon_url` estão populados
3. Verificar query do provider

### Badge não atualiza
1. Verificar se `flutter_app_badger` está instalado
2. Verificar permissões de notificação
3. Verificar se contagem de não lidas está correta

### Deep link não funciona
1. Verificar se deep link está configurado em `go_router`
2. Verificar se payload contém dados corretos
3. Verificar logs de navegação

## Relatório de Testes

Após completar os testes, preencher:

```
Data: ___/___/_____
Dispositivo: ________________
Versão do Android/iOS: ________

Testes Globais: ✓ / ✗
Testes de Comunidade: ✓ / ✗
Testes de Chat: ✓ / ✗
Testes de Moderação: ✓ / ✗
Testes de Badges: ✓ / ✗
Testes de Estados: ✓ / ✗
Testes de Perfil: ✓ / ✗
Testes de Deep Linking: ✓ / ✗

Problemas encontrados:
- ___________________________
- ___________________________

Observações:
- ___________________________
- ___________________________
```
