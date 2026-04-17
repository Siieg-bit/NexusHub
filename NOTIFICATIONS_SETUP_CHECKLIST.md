# Checklist de Configuração - Notificações Push

## 1. Firebase Cloud Messaging (FCM)

### 1.1 Criar Projeto Firebase
- [ ] Acessar [Firebase Console](https://console.firebase.google.com/)
- [ ] Criar novo projeto ou usar existente
- [ ] Ativar Firebase Cloud Messaging
- [ ] Copiar Server API Key

### 1.2 Gerar Service Account
- [ ] Ir para Project Settings → Service Accounts
- [ ] Clicar em "Generate New Private Key"
- [ ] Salvar JSON em local seguro
- [ ] Copiar conteúdo completo do JSON

### 1.3 Configurar Supabase Secrets
- [ ] Ir para Supabase Dashboard → Settings → Secrets
- [ ] Criar novo secret: `FCM_SERVICE_ACCOUNT_JSON`
- [ ] Colar conteúdo completo do JSON
- [ ] Salvar e confirmar

```bash
# Ou via CLI
supabase secrets set FCM_SERVICE_ACCOUNT_JSON "$(cat service-account.json)"
```

## 2. Frontend Flutter

### 2.1 Dependências
- [ ] `firebase_core` adicionado em `pubspec.yaml`
- [ ] `firebase_messaging` adicionado em `pubspec.yaml`
- [ ] `flutter_local_notifications` adicionado em `pubspec.yaml`
- [ ] `flutter_app_badger` adicionado em `pubspec.yaml`
- [ ] `flutter pub get` executado

```yaml
dependencies:
  firebase_core: ^2.24.0
  firebase_messaging: ^14.6.0
  flutter_local_notifications: ^16.1.0
  flutter_app_badger: ^3.0.1
```

### 2.2 Firebase Options
- [ ] `firebase_options.dart` gerado via `flutterfire configure`
- [ ] Arquivo contém configurações para Android e iOS
- [ ] Verificar que `currentPlatform` está correto

```bash
flutterfire configure
```

### 2.3 Android Configuration
- [ ] `google-services.json` presente em `android/app/`
- [ ] `build.gradle` contém Google Services plugin
- [ ] `AndroidManifest.xml` contém permissão:

```xml
<uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
```

- [ ] Verificar `android/app/build.gradle`:

```gradle
apply plugin: 'com.google.gms.google-services'
```

### 2.4 iOS Configuration (se aplicável)
- [ ] APNs certificate configurado no Firebase
- [ ] `ios/Runner/GoogleService-Info.plist` presente
- [ ] Verificar que `ios/Podfile` tem Firebase pods

```ruby
pod 'Firebase/Messaging'
```

## 3. Inicialização do App

### 3.1 Main.dart
- [ ] `PushNotificationService.initialize()` chamado em `main()`
- [ ] Chamada antes de `runApp()`
- [ ] Tratamento de erros implementado

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await PushNotificationService.initialize();
  runApp(const MyApp());
}
```

### 3.2 Providers
- [ ] `notificationProvider` inicializado
- [ ] `communityNotificationProvider` inicializado
- [ ] Realtime subscriptions configuradas

## 4. Backend Supabase

### 4.1 Migrações
- [ ] Migração `062_notification_push_trigger.sql` aplicada
- [ ] Tabela `notifications` existe
- [ ] Tabela `community_members` existe com campos locais
- [ ] Tabela `notification_settings` existe

### 4.2 Edge Functions
- [ ] `push-notification` function criada
- [ ] `index.ts` contém código melhorado
- [ ] Function pode ser chamada via HTTP

```bash
supabase functions deploy push-notification
```

### 4.3 Triggers
- [ ] Trigger `trg_send_push_on_notification` criado
- [ ] Trigger dispara após INSERT em `notifications`
- [ ] pg_net extensão habilitada

```bash
# Verificar trigger
SELECT * FROM information_schema.triggers 
WHERE trigger_name = 'trg_send_push_on_notification';
```

### 4.4 RLS Policies
- [ ] Políticas de acesso configuradas para `notifications`
- [ ] Usuários só veem suas próprias notificações
- [ ] Políticas para `community_members` permitem leitura

## 5. Dados de Teste

### 5.1 Criar Usuários de Teste
- [ ] Usuário A criado com email: `testuser-a@example.com`
- [ ] Usuário B criado com email: `testuser-b@example.com`
- [ ] Ambos com FCM tokens salvos

### 5.2 Criar Comunidade de Teste
- [ ] Comunidade criada
- [ ] Usuário A adicionado como membro
- [ ] Usuário B adicionado como membro
- [ ] Perfis locais criados para ambos

```sql
-- Verificar community_members
SELECT * FROM community_members 
WHERE community_id = 'your-community-id'
AND user_id IN ('user-a-id', 'user-b-id');
```

### 5.3 Criar Posts de Teste
- [ ] Post global criado por Usuário A
- [ ] Post de comunidade criado por Usuário A
- [ ] Ambos com conteúdo de teste

## 6. Testes Básicos

### 6.1 Verificar FCM Token
```sql
-- Verificar se tokens estão salvos
SELECT id, nickname, fcm_token 
FROM profiles 
WHERE email IN ('testuser-a@example.com', 'testuser-b@example.com');
```

### 6.2 Testar Notificação Manual
```sql
-- Inserir notificação de teste
INSERT INTO notifications (
  user_id, 
  type, 
  title, 
  body, 
  actor_id
) VALUES (
  'user-a-id',
  'like',
  'Novo like',
  'Seu post recebeu um like',
  'user-b-id'
);
```

### 6.3 Verificar Logs da Edge Function
- [ ] Acessar Supabase Dashboard → Edge Functions → push-notification
- [ ] Verificar logs recentes
- [ ] Procurar por erros

### 6.4 Verificar Notificação no Dispositivo
- [ ] App aberto no dispositivo
- [ ] Executar INSERT de teste
- [ ] Verificar se notificação aparece
- [ ] Verificar se dados estão corretos

## 7. Validação de Perfil Local

### 7.1 Verificar Dados Locais
```sql
-- Verificar perfil local da comunidade
SELECT 
  cm.user_id,
  cm.local_nickname,
  cm.local_icon_url,
  p.nickname,
  p.icon_url
FROM community_members cm
JOIN profiles p ON cm.user_id = p.id
WHERE cm.community_id = 'your-community-id';
```

### 7.2 Testar Exibição
- [ ] Receber notificação de comunidade
- [ ] Verificar se nickname exibido é o local
- [ ] Verificar se avatar exibido é o local
- [ ] Verificar se não exibe dados globais

## 8. Validação de Badges

### 8.1 Verificar Contagem
```sql
-- Verificar contagem de não lidas
SELECT 
  user_id,
  COUNT(*) as unread_count
FROM notifications
WHERE is_read = false
GROUP BY user_id;
```

### 8.2 Testar Badge
- [ ] Receber 3 notificações não lidas
- [ ] Verificar badge no ícone do app
- [ ] Badge deve mostrar "3"
- [ ] Marcar como lidas
- [ ] Badge deve desaparecer

## 9. Validação de Estados

### 9.1 Foreground
- [ ] App aberto
- [ ] Receber notificação
- [ ] Notificação local aparece
- [ ] Som toca
- [ ] Vibração funciona

### 9.2 Background
- [ ] App minimizado
- [ ] Receber notificação
- [ ] Notificação na bandeja
- [ ] Som toca
- [ ] Clique abre app

### 9.3 Terminated
- [ ] App fechado
- [ ] Receber notificação
- [ ] Notificação na bandeja
- [ ] Clique abre app
- [ ] Deep link funciona

## 10. Troubleshooting

### Problema: Notificações não chegam
- [ ] Verificar `FCM_SERVICE_ACCOUNT_JSON` em Supabase Secrets
- [ ] Verificar se FCM token está em `profiles.fcm_token`
- [ ] Verificar logs da Edge Function
- [ ] Verificar se permissões foram concedidas no app

### Problema: Perfil errado exibido
- [ ] Verificar se `community_members` tem dados preenchidos
- [ ] Verificar se `local_nickname` não é NULL
- [ ] Verificar se `local_icon_url` não é NULL
- [ ] Verificar query do provider

### Problema: Badge não atualiza
- [ ] Verificar se `flutter_app_badger` está instalado
- [ ] Verificar permissões de notificação
- [ ] Verificar se contagem está correta no Supabase
- [ ] Verificar se `updateBadgeFromUnreadCount()` é chamado

### Problema: Deep link não funciona
- [ ] Verificar se deep link está em `go_router`
- [ ] Verificar se payload contém dados corretos
- [ ] Verificar logs de navegação
- [ ] Testar deep link manualmente

## 11. Próximos Passos

- [ ] Testes manuais completos (ver `TESTING_NOTIFICATIONS_GUIDE.md`)
- [ ] Testes automatizados (ver `frontend/test/`)
- [ ] Implementar Web Push (ver `WEB_PUSH_NOTIFICATIONS_GUIDE.md`)
- [ ] Configurar analytics de notificações
- [ ] Monitorar taxa de entrega
- [ ] Otimizar performance

## 12. Documentação Relacionada

- [PUSH_NOTIFICATIONS_IMPROVEMENTS.md](PUSH_NOTIFICATIONS_IMPROVEMENTS.md) - Visão geral das melhorias
- [TESTING_NOTIFICATIONS_GUIDE.md](TESTING_NOTIFICATIONS_GUIDE.md) - Guia de testes manuais
- [WEB_PUSH_NOTIFICATIONS_GUIDE.md](WEB_PUSH_NOTIFICATIONS_GUIDE.md) - Guia de Web Push

## Contato e Suporte

Para problemas ou dúvidas:
1. Verificar logs em Supabase Dashboard
2. Consultar guias de troubleshooting
3. Verificar documentação do Firebase
4. Abrir issue no repositório

---

**Status da Configuração**: [ ] Completo

**Data da Última Atualização**: ___/___/_____

**Responsável**: _________________
