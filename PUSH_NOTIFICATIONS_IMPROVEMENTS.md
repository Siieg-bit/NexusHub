# Melhorias de Notificações Push - NexusHub

## Problema Identificado

As notificações push no celular não estão funcionando de forma confiável quando o app está fechado. O sistema atual usa Firebase Cloud Messaging (FCM), mas há limitações na implementação.

## Solução Implementada

### 1. Melhorias na Edge Function `push-notification`

A Edge Function agora:
- Valida o FCM token antes de enviar
- Limpa tokens inválidos automaticamente
- Respeita as preferências de notificação do usuário
- Envia com prioridade alta para garantir entrega
- Inclui dados contextuais para deep linking

### 2. Melhorias no Service de Push Notifications (Flutter)

#### a) Inicialização Robusta
- Solicita permissões com `provisional: false` para garantir notificações visíveis
- Configura canais de notificação específicos por tipo (chat, social, comunidade, moderação)
- Implementa retry automático em caso de falha

#### b) Tratamento de Mensagens
- Foreground: Exibe notificação local com som e vibração
- Background: Dispara handler top-level para processar sem UI
- Tap: Navega para o contexto correto (post, chat, comunidade)

#### c) Badge e Contagem
- Atualiza badge do app com contagem real de não lidas
- Sincroniza com Supabase em tempo real
- Limpa badge ao abrir notificação

### 3. Melhorias no Provider de Notificações

#### a) Notificações Globais
- Filtra apenas notificações sem `community_id`
- Busca perfil global do ator
- Cache-first com atualização em background

#### b) Notificações de Comunidade
- Filtra por `community_id` específico
- **NOVO**: Busca perfil LOCAL da comunidade (`community_members`)
- Usa `local_nickname` e `local_icon_url` quando disponíveis
- Fallback para perfil global se não houver perfil local

### 4. Correção de Exibição de Perfil

#### Problema
Na tela de notificações de comunidade, estava exibindo o perfil global do usuário (nickname e avatar global) em vez do perfil local da comunidade.

#### Solução
- Query agora faz JOIN com `community_members` para notificações de comunidade
- Na renderização, prioriza dados locais (`local_nickname`, `local_icon_url`)
- Fallback para dados globais se não existir perfil local

## Configuração Necessária

### Firebase Cloud Messaging

1. **Service Account JSON**
   - Obter em: Firebase Console → Project Settings → Service Accounts
   - Adicionar em Supabase Secrets como `FCM_SERVICE_ACCOUNT_JSON`

2. **Android Configuration**
   - `google-services.json` já está configurado em `frontend/android/app/`
   - Verificar que `firebase_messaging` está em `pubspec.yaml`

3. **iOS Configuration** (se aplicável)
   - APNs certificate configurado no Firebase
   - `firebase_options.dart` contém configuração

### Permissões do App

#### Android
```xml
<!-- AndroidManifest.xml -->
<uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
```

#### iOS
- Pedir permissão em tempo de execução via `requestPermission()`

## Fluxo de Notificações

```
1. Ação no app (like, comment, follow, etc)
   ↓
2. Inserção na tabela `notifications`
   ↓
3. Trigger `trg_send_push_on_notification` dispara
   ↓
4. Edge Function `push-notification` chamada via pg_net
   ↓
5. FCM API v1 envia para dispositivo
   ↓
6. Foreground: Exibe notificação local
   Background: Handler top-level processa
   ↓
7. Usuário toca → Deep link navega para contexto
```

## Testes Recomendados

### 1. Notificações Globais
- [ ] Like em post global
- [ ] Comentário em post global
- [ ] Follow
- [ ] Menção em post global

### 2. Notificações de Comunidade
- [ ] Like em post da comunidade
- [ ] Comentário em post da comunidade
- [ ] Menção em post da comunidade
- [ ] Convite para comunidade
- [ ] Atualização de role (leader, curator, etc)

### 3. Verificar Perfil Exibido
- [ ] Nickname local vs global
- [ ] Avatar local vs global
- [ ] Fallback quando não há perfil local

### 4. Estados do App
- [ ] Foreground (app aberto)
- [ ] Background (app minimizado)
- [ ] Terminated (app fechado)

### 5. Badge
- [ ] Badge atualiza com contagem de não lidas
- [ ] Badge limpa ao abrir notificação
- [ ] Badge sincroniza em tempo real

## Troubleshooting

### Notificações não chegam
1. Verificar se FCM token está salvo em `profiles.fcm_token`
2. Verificar se `FCM_SERVICE_ACCOUNT_JSON` está configurado
3. Verificar logs da Edge Function em Supabase
4. Verificar se permissões foram concedidas no dispositivo

### Perfil errado exibido
1. Verificar se `community_members` tem dados preenchidos
2. Verificar se `local_nickname` e `local_icon_url` estão populados
3. Verificar query do provider

### Badge não atualiza
1. Verificar se `flutter_app_badger` está instalado
2. Verificar permissões de notificação
3. Verificar se contagem de não lidas está correta no Supabase

## Commits Relacionados

- Correção de perfil local em notificações de comunidade
- Melhorias em push notification service
- Atualização de notification provider para community profiles
