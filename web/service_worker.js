/**
 * Service Worker para Web Push Notifications
 * 
 * Responsabilidades:
 * - Registrar e gerenciar notificações push
 * - Lidar com eventos de push do servidor
 * - Gerenciar cliques em notificações
 * - Sincronizar dados em background
 * 
 * Eventos:
 * - push: Receber notificação do servidor
 * - notificationclick: Usuário clica na notificação
 * - notificationclose: Usuário fecha a notificação
 * - install: Service Worker instalado
 * - activate: Service Worker ativado
 */

// Versão do Service Worker
const CACHE_VERSION = 'nexushub-v1';
const CACHE_URLS = [
  '/',
  '/index.html',
  '/manifest.json',
  '/favicon.ico'
];

// ─── Instalação ──────────────────────────────────────────────────────────
self.addEventListener('install', (event) => {
  console.log('[Service Worker] Installing...');
  
  event.waitUntil(
    caches.open(CACHE_VERSION).then((cache) => {
      console.log('[Service Worker] Caching app shell');
      return cache.addAll(CACHE_URLS).catch((err) => {
        console.warn('[Service Worker] Cache error:', err);
      });
    })
  );
  
  // Ativar imediatamente
  self.skipWaiting();
});

// ─── Ativação ────────────────────────────────────────────────────────────
self.addEventListener('activate', (event) => {
  console.log('[Service Worker] Activating...');
  
  event.waitUntil(
    caches.keys().then((cacheNames) => {
      return Promise.all(
        cacheNames.map((cacheName) => {
          if (cacheName !== CACHE_VERSION) {
            console.log('[Service Worker] Deleting old cache:', cacheName);
            return caches.delete(cacheName);
          }
        })
      );
    })
  );
  
  // Assumir controle de todas as páginas
  self.clients.claim();
});

// ─── Evento Push (receber notificação) ────────────────────────────────────
self.addEventListener('push', (event) => {
  console.log('[Service Worker] Push received:', event);
  
  if (!event.data) {
    console.warn('[Service Worker] Push sem dados');
    return;
  }

  try {
    const data = event.data.json();
    const { notification, data: notificationData } = data;

    if (!notification) {
      console.warn('[Service Worker] Notificação sem estrutura esperada');
      return;
    }

    const options = {
      body: notification.body || 'Nova notificação',
      icon: '/icons/icon-192x192.png',
      badge: '/icons/badge-72x72.png',
      tag: notificationData?.type || 'notification',
      data: notificationData || {},
      
      // Ações
      actions: [
        { action: 'open', title: 'Abrir' },
        { action: 'close', title: 'Fechar' }
      ],
      
      // Comportamento
      requireInteraction: isHighPriority(notificationData?.type),
      
      // Vibrações
      vibrate: [200, 100, 200],
      
      // Som
      silent: false,
      
      // Badge
      badge: '/icons/badge-72x72.png',
      
      // Timestamp
      timestamp: Date.now(),
    };

    console.log('[Service Worker] Exibindo notificação:', notification.title);

    event.waitUntil(
      self.registration.showNotification(notification.title, options)
        .catch((err) => {
          console.error('[Service Worker] Erro ao exibir notificação:', err);
        })
    );
  } catch (error) {
    console.error('[Service Worker] Erro ao processar push:', error);
  }
});

// ─── Clique em Notificação ───────────────────────────────────────────────
self.addEventListener('notificationclick', (event) => {
  console.log('[Service Worker] Notificação clicada:', event.notification.tag);
  
  event.notification.close();

  const notificationData = event.notification.data;
  const action = event.action;

  // Se ação é 'close', apenas fechar
  if (action === 'close') {
    return;
  }

  // Construir URL baseado no tipo de notificação
  const url = buildUrlFromNotification(notificationData);

  console.log('[Service Worker] Navegando para:', url);

  event.waitUntil(
    clients.matchAll({ type: 'window', includeUncontrolled: true })
      .then((clientList) => {
        // Procurar janela já aberta
        for (let client of clientList) {
          if (client.url === url && 'focus' in client) {
            console.log('[Service Worker] Focando janela existente');
            return client.focus();
          }
        }

        // Abrir nova janela
        if (clients.openWindow) {
          console.log('[Service Worker] Abrindo nova janela');
          return clients.openWindow(url);
        }
      })
      .catch((err) => {
        console.error('[Service Worker] Erro ao lidar com clique:', err);
      })
  );
});

// ─── Fechar Notificação ──────────────────────────────────────────────────
self.addEventListener('notificationclose', (event) => {
  console.log('[Service Worker] Notificação fechada:', event.notification.tag);
  
  // Aqui você pode registrar analytics ou fazer cleanup
  // Por exemplo, marcar notificação como vista
});

// ─── Fetch (cache-first strategy) ────────────────────────────────────────
self.addEventListener('fetch', (event) => {
  // Ignorar requisições não-GET
  if (event.request.method !== 'GET') {
    return;
  }

  // Ignorar requisições para APIs (deixar ir para rede)
  if (event.request.url.includes('/functions/') || 
      event.request.url.includes('/api/')) {
    return;
  }

  event.respondWith(
    caches.match(event.request)
      .then((response) => {
        if (response) {
          console.log('[Service Worker] Servindo do cache:', event.request.url);
          return response;
        }

        return fetch(event.request)
          .then((response) => {
            // Não cachear respostas não-ok
            if (!response || response.status !== 200 || response.type === 'error') {
              return response;
            }

            // Clonar resposta para cachear
            const responseToCache = response.clone();
            caches.open(CACHE_VERSION).then((cache) => {
              cache.put(event.request, responseToCache);
            });

            return response;
          })
          .catch((err) => {
            console.warn('[Service Worker] Fetch error:', err);
            // Retornar página offline se disponível
            return caches.match('/offline.html')
              .catch(() => new Response('Offline'));
          });
      })
  );
});

// ─── Funções Auxiliares ──────────────────────────────────────────────────

/**
 * Determinar se notificação é de alta prioridade
 * (requer interação do usuário)
 */
function isHighPriority(type) {
  const highPriorityTypes = [
    'moderation',
    'strike',
    'ban',
    'community_invite',
    'chat_mention',
    'mention'
  ];
  return highPriorityTypes.includes(type);
}

/**
 * Construir URL de navegação baseado no tipo de notificação
 */
function buildUrlFromNotification(data) {
  const baseUrl = self.location.origin;

  if (!data || !data.type) {
    return baseUrl;
  }

  const { type, post_id, community_id, chat_thread_id, actor_id, wiki_id } = data;

  switch (type) {
    // Posts e conteúdo
    case 'like':
    case 'comment':
    case 'wall_post':
    case 'mention':
      if (post_id) {
        return `${baseUrl}/post/${post_id}`;
      }
      break;

    // Comunidades
    case 'community_invite':
    case 'community_update':
    case 'join_request':
    case 'role_change':
      if (community_id) {
        return `${baseUrl}/community/${community_id}`;
      }
      break;

    // Chat
    case 'chat_message':
    case 'chat_mention':
    case 'dm_invite':
      if (chat_thread_id) {
        return `${baseUrl}/chat/${chat_thread_id}`;
      }
      break;

    // Perfil
    case 'follow':
      if (actor_id) {
        return `${baseUrl}/profile/${actor_id}`;
      }
      break;

    // Wiki
    case 'wiki_approved':
    case 'wiki_rejected':
      if (wiki_id) {
        return `${baseUrl}/wiki/${wiki_id}`;
      }
      break;

    // Gamificação
    case 'level_up':
    case 'achievement':
    case 'check_in_streak':
      return `${baseUrl}/profile`;

    // Moderação
    case 'moderation':
    case 'strike':
    case 'ban':
      return `${baseUrl}/notifications`;

    default:
      return baseUrl;
  }

  return baseUrl;
}

/**
 * Enviar mensagem para todos os clientes
 */
function broadcastToClients(message) {
  self.clients.matchAll().then((clients) => {
    clients.forEach((client) => {
      client.postMessage(message);
    });
  });
}

/**
 * Log com timestamp
 */
function logWithTimestamp(message) {
  const timestamp = new Date().toISOString();
  console.log(`[${timestamp}] ${message}`);
}

// ─── Sincronização em Background (opcional) ──────────────────────────────
self.addEventListener('sync', (event) => {
  console.log('[Service Worker] Background sync:', event.tag);

  if (event.tag === 'sync-notifications') {
    event.waitUntil(
      // Sincronizar notificações com servidor
      fetch('/api/notifications/sync')
        .then((response) => {
          if (response.ok) {
            console.log('[Service Worker] Notificações sincronizadas');
            broadcastToClients({ type: 'notifications-synced' });
          }
        })
        .catch((err) => {
          console.error('[Service Worker] Erro ao sincronizar:', err);
        })
    );
  }
});

console.log('[Service Worker] Loaded and ready');
