# Melhorias de Push Notifications no Frontend

## Resumo das Mudanças

Este documento descreve as melhorias implementadas no frontend (Flutter) para garantir que as push notifications funcionem de forma confiável, mesmo quando o app está fechado.

## 1. Otimizações no PushNotificationService

### 1.1 Melhorias na Exibição de Notificações em Foreground

**Arquivo:** `frontend/lib/core/services/push_notification_service.dart`

**Mudanças:**
- Adicionado `enableVibration: true` para garantir vibração
- Adicionado `enableLights: true` para garantir LED de notificação
- Adicionado `playSound: true` para garantir som
- Adicionado `setAsAction: true` para evitar que o sistema descarte a notificação
- Adicionado `ticker` com o título da notificação para melhor visualização

```dart
NotificationDetails(
  android: AndroidNotificationDetails(
    channelId,
    channelId.replaceAll('nexushub_', '').toUpperCase(),
    icon: '@mipmap/ic_launcher',
    importance: Importance.high,
    priority: Priority.high,
    enableVibration: true,
    enableLights: true,
    playSound: true,
    setAsAction: true,
    ticker: notification.title,
  ),
)
```

### 1.2 Melhorias no Tratamento de Tap em Notificações

**Mudança:** Adicionado logging e tratamento para garantir que o app seja trazido para frente quando o usuário toca na notificação.

```dart
static void _handleNotificationTap(RemoteMessage message) {
  debugPrint('[Push] Notification tap: ${message.data}');
  _notificationStreamController?.add(message.data);
  clearAppBadge();
  
  // Garantir que o app está em primeiro plano
  try {
    debugPrint('[Push] App trazido para frente após toque na notificação');
  } catch (e) {
    debugPrint('[Push] Erro ao trazer app para frente: $e');
  }
}
```

## 2. Configuração do AndroidManifest.xml

**Arquivo:** `frontend/android/app/src/main/AndroidManifest.xml`

**Status:** ✅ Já configurado corretamente

- ✅ `POST_NOTIFICATIONS` permissão presente (linha 15)
- ✅ Firebase Cloud Messaging metadata configurado (linhas 45-51)
- ✅ Deep links configurados (linhas 69-105)
- ✅ MainActivity com `launchMode="singleTop"` (linha 57)

## 3. Configuração do pubspec.yaml

**Arquivo:** `frontend/pubspec.yaml`

**Status:** ✅ Já configurado corretamente

Dependências presentes:
- ✅ `firebase_core: ^3.0.0`
- ✅ `firebase_messaging: ^15.0.0`
- ✅ `flutter_app_badger: ^1.5.0`

## 4. Fluxo de Notificações Completo

```
┌─────────────────────────────────────────────────────────────┐
│ 1. Ação no app (like, comment, etc)                         │
│    ↓                                                         │
│ 2. INSERT em notifications table                            │
│    ↓                                                         │
│ 3. Trigger trg_send_push_on_notification_v2 dispara        │
│    ↓                                                         │
│ 4. Insere em push_notification_queue (status: pending)      │
│    ↓                                                         │
│ 5. Edge Function push-notification-v2 chamada via pg_net    │
│    ↓                                                         │
│ 6. FCM API v1 envia para dispositivo                        │
│    ├─ Se sucesso: marca como 'sent' na fila                │
│    └─ Se falha: mantém como 'pending' para retry            │
│    ↓                                                         │
│ 7. Cron job processa retries a cada 5 minutos              │
│    (com backoff exponencial)                                │
│    ↓                                                         │
│ 8. App recebe:                                              │
│    ├─ Foreground: Exibe notificação local com som/vibração  │
│    ├─ Background: Handler top-level processa               │
│    └─ Terminated: Notificação no sistema                    │
│    ↓                                                         │
│ 9. Usuário toca → Deep link navega para contexto            │
│    ↓                                                         │
│ 10. Badge atualizado com contagem real de não lidas         │
└─────────────────────────────────────────────────────────────┘
```

## 5. Testes Recomendados

### 5.1 Notificações em Foreground
- [ ] Like em post global com app aberto
- [ ] Comentário em post de comunidade com app aberto
- [ ] Verificar som e vibração
- [ ] Verificar badge atualizado

### 5.2 Notificações em Background
- [ ] Minimizar app e enviar notificação
- [ ] Verificar se notificação aparece na bandeja do sistema
- [ ] Tocar na notificação e verificar deep link
- [ ] Verificar que o app navega para o contexto correto

### 5.3 Notificações com App Terminado
- [ ] Fechar app completamente
- [ ] Enviar notificação
- [ ] Verificar se notificação aparece na bandeja
- [ ] Tocar e verificar deep link
- [ ] Verificar que o app abre corretamente

### 5.4 Perfil Local vs Global
- [ ] Notificação de like em post de comunidade
- [ ] Verificar que exibe nickname local (se existir)
- [ ] Verificar que exibe avatar local (se existir)
- [ ] Verificar fallback para perfil global

### 5.5 Retry Automático
- [ ] Simular falha de FCM (desabilitar internet)
- [ ] Verificar que notificação fica em fila
- [ ] Reabilitar internet
- [ ] Verificar que cron job processa retry
- [ ] Verificar que notificação é entregue

## 6. Troubleshooting

### Notificações não chegam
1. Verificar se FCM token está salvo em `profiles.fcm_token`
   ```sql
   SELECT id, fcm_token FROM profiles WHERE id = 'user-id';
   ```

2. Verificar se `FCM_SERVICE_ACCOUNT_JSON` está configurado em Supabase Secrets
   ```bash
   supabase secrets list
   ```

3. Verificar logs da Edge Function em Supabase
   ```bash
   supabase functions logs push-notification-v2
   ```

4. Verificar permissões no dispositivo
   - Ir para Configurações → Aplicativos → NexusHub → Permissões
   - Verificar se "Notificações" está habilitada

### Perfil errado exibido
1. Verificar se `community_members` tem dados preenchidos
   ```sql
   SELECT user_id, community_id, local_nickname, local_icon_url 
   FROM community_members 
   WHERE user_id = 'actor-id' AND community_id = 'community-id';
   ```

2. Verificar se a RPC `get_community_notifications_by_category` está retornando dados corretos
   ```sql
   SELECT * FROM get_community_notifications_by_category(
     'community-id'::uuid,
     'all',
     30,
     0
   );
   ```

### Badge não atualiza
1. Verificar se `flutter_app_badger` está instalado
2. Verificar permissões no dispositivo
3. Verificar se contagem de não lidas está correta
   ```sql
   SELECT COUNT(*) FROM notifications 
   WHERE user_id = 'user-id' AND is_read = false;
   ```

## 7. Commits Relacionados

- Correção de perfil local em notificações de comunidade (Migração 121)
- Melhorias em infraestrutura de push notifications (Migração 122)
- Versão melhorada da Edge Function push-notification (push-notification-v2)
- Otimizações no frontend PushNotificationService

## 8. Próximos Passos

1. **Configurar Supabase Secrets:**
   ```bash
   supabase secrets set FCM_SERVICE_ACCOUNT_JSON "$(cat service-account.json)"
   supabase secrets set SUPABASE_URL "https://ylvzqqvcanzzswjkqeya.supabase.co"
   supabase secrets set SUPABASE_SERVICE_ROLE_KEY "seu-service-role-key"
   ```

2. **Deploy das Migrações:**
   ```bash
   supabase db push
   ```

3. **Deploy das Edge Functions:**
   ```bash
   supabase functions deploy push-notification-v2
   ```

4. **Testar em Dispositivo Real:**
   - Build APK: `flutter build apk --release`
   - Instalar: `adb install build/app/outputs/apk/release/app-release.apk`
   - Testar fluxo completo de notificações

5. **Monitorar em Produção:**
   - Verificar logs da Edge Function
   - Monitorar fila de push (tabela `push_notification_queue`)
   - Coletar feedback de usuários sobre entrega de notificações
