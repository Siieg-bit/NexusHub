# Guia de Testes - Web Push Notifications

## Pré-requisitos

1. **Configuração Completa**
   - VAPID keys geradas
   - Supabase Secrets configurados
   - Service Worker registrado
   - Tabela push_subscriptions criada
   - Edge Function deployada

2. **Navegador Compatível**
   - Chrome/Chromium 50+
   - Firefox 48+
   - Edge 17+
   - Opera 37+
   - Safari 16+ (parcial)

3. **Ambiente**
   - Servidor HTTPS (obrigatório para Web Push)
   - Localhost funciona com `http://localhost:3000`

## Testes Automatizados

### Executar Testes

```bash
cd frontend
flutter test test/web_push_notifications_test.dart
```

### Cobertura de Testes

- ✅ Extração de dados de subscription
- ✅ Validação de campos obrigatórios
- ✅ Estrutura de payload
- ✅ Tipos de notificação
- ✅ Múltiplas plataformas
- ✅ Transições de status
- ✅ Timestamps
- ✅ Validação de endpoint
- ✅ Múltiplas subscriptions
- ✅ VAPID keys
- ✅ Deep linking
- ✅ Campos opcionais
- ✅ Cleanup de subscriptions

## Testes Manuais

### 1. Verificar Suporte

```javascript
// No console do navegador
console.log('Service Workers:', 'serviceWorker' in navigator);
console.log('Push API:', 'PushManager' in window);
console.log('Notifications:', 'Notification' in window);
```

**Resultado esperado:**
```
Service Workers: true
Push API: true
Notifications: true
```

### 2. Registrar Service Worker

```javascript
// No console do navegador
navigator.serviceWorker.register('/service_worker.js')
  .then(reg => {
    console.log('✅ Service Worker registrado:', reg.scope);
  })
  .catch(err => {
    console.error('❌ Erro:', err);
  });
```

**Resultado esperado:**
```
✅ Service Worker registrado: https://localhost:3000/
```

### 3. Solicitar Permissão

```javascript
// No console do navegador
Notification.requestPermission()
  .then(permission => {
    console.log('✅ Permissão:', permission);
  });
```

**Resultado esperado:**
```
✅ Permissão: granted
```

### 4. Obter Push Subscription

```javascript
// No console do navegador
navigator.serviceWorker.ready
  .then(reg => reg.pushManager.getSubscription())
  .then(sub => {
    if (sub) {
      console.log('✅ Subscription encontrada');
      console.log('Endpoint:', sub.endpoint.substring(0, 50) + '...');
      console.log('Keys:', sub.getKey('auth'), sub.getKey('p256dh'));
    } else {
      console.log('❌ Nenhuma subscription encontrada');
    }
  });
```

**Resultado esperado:**
```
✅ Subscription encontrada
Endpoint: https://fcm.googleapis.com/fcm/send/...
Keys: [ArrayBuffer] [ArrayBuffer]
```

### 5. Testar Notificação Local

```javascript
// No console do navegador
navigator.serviceWorker.ready
  .then(reg => {
    reg.showNotification('Teste Local', {
      body: 'Esta é uma notificação de teste',
      icon: '/icons/icon-192x192.png',
      badge: '/icons/badge-72x72.png',
    });
  });
```

**Resultado esperado:**
- Notificação aparece na bandeja do navegador
- Título: "Teste Local"
- Corpo: "Esta é uma notificação de teste"

### 6. Testar Clique em Notificação

```javascript
// Adicionar listener no Service Worker
self.addEventListener('notificationclick', (event) => {
  console.log('✅ Notificação clicada:', event.notification.title);
  event.notification.close();
  clients.openWindow('https://localhost:3000/');
});
```

**Resultado esperado:**
- Clique na notificação abre o app
- Notificação fecha automaticamente

### 7. Testar Subscription no Supabase

```sql
-- No SQL Editor do Supabase
SELECT 
  id,
  user_id,
  platform,
  endpoint,
  is_active,
  created_at,
  last_used_at
FROM push_subscriptions
WHERE platform = 'web'
ORDER BY created_at DESC
LIMIT 10;
```

**Resultado esperado:**
- Subscription do usuário com platform='web'
- endpoint preenchido
- is_active=true

### 8. Testar Envio de Web Push

```sql
-- Inserir notificação de teste
INSERT INTO notifications (
  user_id,
  type,
  title,
  body,
  actor_id
) VALUES (
  'seu-user-id',
  'like',
  'Teste Web Push',
  'Esta é uma notificação de teste do Web Push',
  'outro-user-id'
);
```

**Resultado esperado:**
- Notificação aparece no navegador
- Mesmo com app fechado
- Clique navega para o contexto

### 9. Testar Deep Linking

**Para Post:**
```sql
INSERT INTO notifications (
  user_id, type, title, body, actor_id, post_id
) VALUES (
  'seu-user-id', 'like', 'Novo like', 'Seu post recebeu um like', 'outro-user-id', 'post-123'
);
```

Clique deve navegar para `/post/post-123`

**Para Comunidade:**
```sql
INSERT INTO notifications (
  user_id, type, title, body, actor_id, community_id
) VALUES (
  'seu-user-id', 'community_invite', 'Convite', 'Você foi convidado', 'outro-user-id', 'community-456'
);
```

Clique deve navegar para `/community/community-456`

### 10. Testar com App Fechado

1. Abrir app no navegador
2. Permitir notificações
3. Fechar aba/navegador completamente
4. Inserir notificação de teste no Supabase
5. Verificar se notificação aparece na bandeja

**Resultado esperado:**
- Notificação aparece mesmo com app fechado
- Clique abre app e navega para contexto

### 11. Testar Múltiplas Subscriptions

1. Abrir app em 2 abas diferentes
2. Permitir notificações em ambas
3. Verificar que ambas têm subscriptions diferentes
4. Inserir notificação de teste
5. Verificar que ambas recebem

**Resultado esperado:**
- 2 subscriptions no Supabase
- Ambas recebem notificação

### 12. Testar Limpeza de Subscriptions Inativas

```sql
-- Marcar subscription como inativa
UPDATE push_subscriptions
SET is_active = false
WHERE platform = 'web'
LIMIT 1;

-- Executar função de cleanup
SELECT cleanup_inactive_push_subscriptions();
```

**Resultado esperado:**
- Subscriptions inativas por mais de 30 dias são deletadas

## Checklist de Testes

### Suporte e Permissões
- [ ] Service Worker registra com sucesso
- [ ] Permissão de notificação solicita corretamente
- [ ] Push API disponível
- [ ] Notification API disponível

### Subscriptions
- [ ] Subscription criada ao permitir notificações
- [ ] Subscription salva no Supabase
- [ ] Endpoint preenchido
- [ ] Auth key preenchida
- [ ] P256dh key preenchida
- [ ] is_active = true

### Notificações
- [ ] Notificação local aparece
- [ ] Notificação push aparece
- [ ] Título correto
- [ ] Corpo correto
- [ ] Ícone exibido
- [ ] Badge exibido

### Deep Linking
- [ ] Post: /post/{post_id}
- [ ] Comunidade: /community/{community_id}
- [ ] Chat: /chat/{chat_thread_id}
- [ ] Perfil: /profile/{actor_id}
- [ ] Wiki: /wiki/{wiki_id}

### Estados
- [ ] Foreground: Notificação aparece
- [ ] Background: Notificação aparece
- [ ] Terminated: Notificação aparece

### Múltiplas Plataformas
- [ ] Web: Funciona
- [ ] Android: Funciona (FCM)
- [ ] iOS: Funciona (APNs)

### Performance
- [ ] Notificação entrega em < 5 segundos
- [ ] Sem lag ao receber
- [ ] Sem consumo excessivo de memória

### Cleanup
- [ ] Subscriptions inativas removidas após 30 dias
- [ ] Subscriptions expiradas marcadas como inativas
- [ ] last_used_at atualizado ao enviar

## Troubleshooting

### Service Worker não registra

**Problema:** `DOMException: Failed to register a ServiceWorker`

**Solução:**
1. Verificar se está em HTTPS ou localhost
2. Verificar se `service_worker.js` existe em `/web/`
3. Verificar CORS headers
4. Limpar cache do navegador

```javascript
// Limpar registros
navigator.serviceWorker.getRegistrations()
  .then(regs => {
    regs.forEach(reg => reg.unregister());
  });
```

### Permissão negada

**Problema:** `Notification.permission === 'denied'`

**Solução:**
1. Ir em configurações do navegador
2. Encontrar site
3. Resetar permissão de notificação
4. Tentar novamente

### Subscription não criada

**Problema:** `pushManager.subscribe()` retorna null

**Solução:**
1. Verificar se permissão foi concedida
2. Verificar VAPID public key
3. Verificar se navegador suporta
4. Verificar console para erros

### Notificação não aparece

**Problema:** Notificação não é exibida

**Solução:**
1. Verificar se subscription existe
2. Verificar logs da Edge Function
3. Verificar se endpoint é válido
4. Verificar se VAPID keys estão corretas
5. Verificar se payload é válido

### Deep link não funciona

**Problema:** Clique em notificação não navega

**Solução:**
1. Verificar se dados estão no payload
2. Verificar se rota existe em go_router
3. Verificar logs de navegação
4. Testar deep link manualmente

## Performance

### Métricas Esperadas

| Métrica | Esperado | Crítico |
|---------|----------|---------|
| Tempo de entrega | < 5s | > 30s |
| Taxa de sucesso | > 95% | < 80% |
| Latência | < 1s | > 5s |
| Memória | < 10MB | > 50MB |

### Monitoramento

```sql
-- Verificar taxa de sucesso
SELECT 
  COUNT(*) as total,
  COUNT(CASE WHEN last_used_at IS NOT NULL THEN 1 END) as used,
  ROUND(100.0 * COUNT(CASE WHEN last_used_at IS NOT NULL THEN 1 END) / COUNT(*), 2) as success_rate
FROM push_subscriptions
WHERE platform = 'web'
AND created_at > NOW() - INTERVAL '24 hours';
```

## Próximos Passos

- [ ] Implementar retry automático
- [ ] Adicionar analytics
- [ ] Monitorar taxa de entrega
- [ ] Otimizar payload
- [ ] Testar em diferentes navegadores
- [ ] Testar em diferentes redes
- [ ] Testar com muitas subscriptions

## Recursos

- [Web Push Protocol (RFC 8030)](https://tools.ietf.org/html/rfc8030)
- [VAPID Specification](https://tools.ietf.org/html/draft-thomson-webpush-vapid)
- [MDN: Web Push API](https://developer.mozilla.org/en-US/docs/Web/API/Push_API)
- [MDN: Service Worker API](https://developer.mozilla.org/en-US/docs/Web/API/Service_Worker_API)
