# Guia de Implementação: Web Push Notifications

## Visão Geral

Este guia descreve como implementar Web Push Notifications no NexusHub para garantir que os usuários recebam notificações mesmo quando o app está fechado (no navegador web).

## Tecnologias

- **Service Worker**: Para registrar e gerenciar notificações em background
- **Push API**: Para receber notificações do servidor
- **Notification API**: Para exibir notificações ao usuário
- **Firebase Cloud Messaging (FCM)**: Backend de entrega

## Arquitetura

```
┌─────────────────────────────────────────┐
│         Aplicação Web (Flutter Web)     │
├─────────────────────────────────────────┤
│  1. Registrar Service Worker            │
│  2. Solicitar permissão de notificação  │
│  3. Obter Push Subscription             │
│  4. Enviar subscription para Supabase   │
└─────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────┐
│      Service Worker (Background)        │
├─────────────────────────────────────────┤
│  1. Escutar eventos 'push'              │
│  2. Exibir notificação                  │
│  3. Lidar com cliques                   │
│  4. Navegar para contexto               │
└─────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────┐
│    Firebase Cloud Messaging (FCM)       │
├─────────────────────────────────────────┤
│  1. Receber payload do servidor         │
│  2. Enviar para Service Worker          │
│  3. Exibir notificação no navegador     │
└─────────────────────────────────────────┘
```

## Implementação

### 1. Service Worker (`web/service_worker.js`)

```javascript
// Registrar Service Worker
if ('serviceWorker' in navigator) {
  navigator.serviceWorker.register('service_worker.js')
    .then(reg => console.log('Service Worker registrado'))
    .catch(err => console.error('Erro ao registrar Service Worker:', err));
}

// Escutar eventos de push
self.addEventListener('push', (event) => {
  if (!event.data) return;

  const data = event.data.json();
  const options = {
    body: data.notification.body,
    icon: '/icons/icon-192x192.png',
    badge: '/icons/badge-72x72.png',
    data: data.data,
    tag: data.data.type,
    requireInteraction: data.data.type === 'moderation' || data.data.type === 'ban',
    actions: [
      { action: 'open', title: 'Abrir' },
      { action: 'close', title: 'Fechar' }
    ]
  };

  event.waitUntil(
    self.registration.showNotification(data.notification.title, options)
  );
});

// Lidar com cliques em notificações
self.addEventListener('notificationclick', (event) => {
  event.notification.close();

  const data = event.notification.data;
  const url = buildUrlFromNotification(data);

  event.waitUntil(
    clients.matchAll({ type: 'window', includeUncontrolled: true })
      .then(clientList => {
        // Procurar janela já aberta
        for (let client of clientList) {
          if (client.url === url && 'focus' in client) {
            return client.focus();
          }
        }
        // Abrir nova janela
        if (clients.openWindow) {
          return clients.openWindow(url);
        }
      })
  );
});

function buildUrlFromNotification(data) {
  const baseUrl = self.location.origin;
  
  switch (data.type) {
    case 'like':
    case 'comment':
    case 'wall_post':
      return `${baseUrl}/post/${data.post_id}`;
    
    case 'community_invite':
    case 'community_update':
      return `${baseUrl}/community/${data.community_id}`;
    
    case 'chat_message':
      return `${baseUrl}/chat/${data.chat_thread_id}`;
    
    case 'follow':
      return `${baseUrl}/profile/${data.actor_id}`;
    
    default:
      return baseUrl;
  }
}
```

### 2. Inicialização de Push (`lib/core/services/web_push_service.dart`)

```dart
import 'dart:html' as html;
import 'package:flutter/foundation.dart';

class WebPushService {
  static const String _vapidPublicKey = 'YOUR_VAPID_PUBLIC_KEY';

  static Future<void> initialize() async {
    if (!kIsWeb) return;

    try {
      // Registrar Service Worker
      await _registerServiceWorker();

      // Solicitar permissão
      final permission = await _requestPermission();
      if (permission != 'granted') {
        debugPrint('[WebPush] Permissão negada');
        return;
      }

      // Obter subscription
      final subscription = await _getPushSubscription();
      if (subscription != null) {
        await _savePushSubscription(subscription);
      }

      debugPrint('[WebPush] Inicializado com sucesso');
    } catch (e) {
      debugPrint('[WebPush] Erro ao inicializar: $e');
    }
  }

  static Future<void> _registerServiceWorker() async {
    if (!kIsWeb) return;

    try {
      final serviceWorkerContainer = html.window.navigator.serviceWorker;
      if (serviceWorkerContainer == null) {
        throw Exception('Service Workers não suportados');
      }

      await serviceWorkerContainer.register('service_worker.js');
      debugPrint('[WebPush] Service Worker registrado');
    } catch (e) {
      debugPrint('[WebPush] Erro ao registrar Service Worker: $e');
    }
  }

  static Future<String?> _requestPermission() async {
    if (!kIsWeb) return null;

    try {
      final permission = await html.Notification.requestPermission();
      debugPrint('[WebPush] Permissão: $permission');
      return permission;
    } catch (e) {
      debugPrint('[WebPush] Erro ao solicitar permissão: $e');
      return null;
    }
  }

  static Future<Map<String, dynamic>?> _getPushSubscription() async {
    if (!kIsWeb) return null;

    try {
      final serviceWorkerContainer = html.window.navigator.serviceWorker;
      if (serviceWorkerContainer == null) return null;

      final registration = await serviceWorkerContainer.ready;
      final subscription = await registration.pushManager?.getSubscription();

      if (subscription != null) {
        return {
          'endpoint': subscription.endpoint,
          'auth': subscription.getKey('auth'),
          'p256dh': subscription.getKey('p256dh'),
        };
      }

      // Se não houver subscription, criar uma
      return await _createPushSubscription(registration);
    } catch (e) {
      debugPrint('[WebPush] Erro ao obter subscription: $e');
      return null;
    }
  }

  static Future<Map<String, dynamic>?> _createPushSubscription(dynamic registration) async {
    try {
      final subscription = await registration.pushManager?.subscribe(
        userVisibleOnly: true,
        applicationServerKey: _vapidPublicKey,
      );

      if (subscription != null) {
        return {
          'endpoint': subscription.endpoint,
          'auth': subscription.getKey('auth'),
          'p256dh': subscription.getKey('p256dh'),
        };
      }
    } catch (e) {
      debugPrint('[WebPush] Erro ao criar subscription: $e');
    }
    return null;
  }

  static Future<void> _savePushSubscription(Map<String, dynamic> subscription) async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) return;

    try {
      await SupabaseService.table('push_subscriptions').upsert({
        'user_id': userId,
        'endpoint': subscription['endpoint'],
        'auth': subscription['auth'],
        'p256dh': subscription['p256dh'],
        'platform': 'web',
        'created_at': DateTime.now().toIso8601String(),
      }, onConflict: 'user_id,platform');

      debugPrint('[WebPush] Subscription salva');
    } catch (e) {
      debugPrint('[WebPush] Erro ao salvar subscription: $e');
    }
  }
}
```

### 3. Tabela de Subscriptions (`migrations/XXX_web_push_subscriptions.sql`)

```sql
-- Tabela para armazenar subscriptions de Web Push
CREATE TABLE public.push_subscriptions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  endpoint TEXT NOT NULL,
  auth TEXT NOT NULL,
  p256dh TEXT NOT NULL,
  platform TEXT NOT NULL DEFAULT 'web', -- 'web', 'android', 'ios'
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  
  UNIQUE(user_id, platform, endpoint)
);

CREATE INDEX idx_push_subscriptions_user ON public.push_subscriptions(user_id);
CREATE INDEX idx_push_subscriptions_platform ON public.push_subscriptions(platform);
```

### 4. Edge Function para Web Push

```typescript
// backend/supabase/functions/web-push-notification/index.ts
import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const vapidPrivateKey = Deno.env.get("VAPID_PRIVATE_KEY");
const vapidPublicKey = Deno.env.get("VAPID_PUBLIC_KEY");
const vapidSubject = Deno.env.get("VAPID_SUBJECT"); // mailto:seu-email@example.com

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok");
  }

  try {
    const payload = await req.json();
    const { user_id, title, body, data } = payload;

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? ""
    );

    // Buscar subscriptions do usuário
    const { data: subscriptions } = await supabase
      .from("push_subscriptions")
      .select("*")
      .eq("user_id", user_id)
      .eq("platform", "web")
      .eq("is_active", true);

    if (!subscriptions || subscriptions.length === 0) {
      return new Response(
        JSON.stringify({ message: "No web push subscriptions" }),
        { status: 200 }
      );
    }

    // Enviar para cada subscription
    const results = await Promise.all(
      subscriptions.map((sub) =>
        sendWebPush({
          endpoint: sub.endpoint,
          auth: sub.auth,
          p256dh: sub.p256dh,
          payload: { title, body, data },
        })
      )
    );

    return new Response(JSON.stringify({ results }), { status: 200 });
  } catch (error) {
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 500 }
    );
  }
});

async function sendWebPush(options: {
  endpoint: string;
  auth: string;
  p256dh: string;
  payload: Record<string, unknown>;
}) {
  // Implementar envio de Web Push usando web-push library
  // ou implementação manual de VAPID
  
  try {
    const response = await fetch(options.endpoint, {
      method: "POST",
      headers: {
        "Content-Type": "application/octet-stream",
        "TTL": "24",
      },
      body: JSON.stringify(options.payload),
    });

    return { success: response.ok };
  } catch (e) {
    console.error(`Erro ao enviar Web Push: ${e}`);
    return { success: false, error: e.message };
  }
}
```

## Configuração

### 1. VAPID Keys

Gerar VAPID keys (necessárias para Web Push):

```bash
# Instalar web-push CLI
npm install -g web-push

# Gerar keys
web-push generate-vapid-keys

# Adicionar em Supabase Secrets
VAPID_PUBLIC_KEY=...
VAPID_PRIVATE_KEY=...
VAPID_SUBJECT=mailto:seu-email@example.com
```

### 2. Service Worker

Colocar `web/service_worker.js` na raiz do projeto web.

### 3. Inicializar no App

```dart
void main() async {
  // ... inicialização do app
  
  if (kIsWeb) {
    await WebPushService.initialize();
  }
  
  runApp(const MyApp());
}
```

## Testes

### 1. Verificar Service Worker

```javascript
// No console do navegador
navigator.serviceWorker.getRegistrations()
  .then(registrations => console.log(registrations));
```

### 2. Testar Push Notification

```javascript
// No console do Service Worker
self.registration.showNotification('Teste', {
  body: 'Notificação de teste',
  icon: '/icons/icon-192x192.png'
});
```

### 3. Verificar Subscriptions

```dart
// No app Flutter Web
final subscriptions = await supabase
  .from('push_subscriptions')
  .select()
  .eq('user_id', userId)
  .eq('platform', 'web');
print(subscriptions);
```

## Troubleshooting

### Notificações não aparecem
1. Verificar se Service Worker está registrado
2. Verificar se permissão foi concedida
3. Verificar se subscription foi salva no Supabase
4. Verificar logs do Service Worker

### Service Worker não registra
1. Verificar se `service_worker.js` está na raiz do projeto web
2. Verificar CORS headers
3. Verificar console do navegador para erros

### Permissão negada
1. Verificar configurações de notificação do navegador
2. Tentar em modo incógnito
3. Limpar cache e cookies

## Próximos Passos

- [ ] Implementar retry automático para subscriptions inválidas
- [ ] Adicionar suporte a ações de notificação (abrir, fechar, etc)
- [ ] Implementar sincronização de background
- [ ] Adicionar analytics de notificações
- [ ] Testar em diferentes navegadores (Chrome, Firefox, Safari, Edge)
