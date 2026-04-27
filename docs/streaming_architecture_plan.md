# Plano de Ação: Arquitetura de Streaming Multi-Plataforma no NexusHub

**Baseado em engenharia reversa do Rave (Wemesh Inc.)**
**Data:** Abril de 2026

---

## Contexto e Motivação

A análise dos arquivos DEX do APK do Rave revelou que o aplicativo não usa uma única metodologia para integrar plataformas de streaming. Ao contrário, o Rave emprega **três arquiteturas distintas e paralelas**, cada uma otimizada para o nível de proteção e abertura de API de cada serviço. Este plano detalha como replicar essa arquitetura no NexusHub, adaptando-a à stack existente (Flutter + Supabase + Deno Edge Functions).

O ponto central da descoberta é que o Rave possui um **servidor relay próprio** (`https://api.red.wemesh.ca/`, servido via Fastly CDN) que atua como intermediário para plataformas com DRM, enquanto para plataformas abertas o app lida diretamente com as APIs públicas ou com iframes.

---

## Visão Geral das Três Arquiteturas

| Camada | Plataformas | Seleção de Vídeo | Reprodução |
|---|---|---|---|
| **1 — Embed** | YouTube, Vimeo, Kick, Dailymotion, WEB | WebView + interceptação de URL | Iframe HTML5 com JS API |
| **2 — HLS Direto** | Twitch, Tubi, Pluto TV | WebView + interceptação de URL | API pública → manifest `.m3u8` → player nativo |
| **3 — Relay + DRM** | Netflix, Disney+, Amazon Prime, HBO Max | WebView (login) → captura de cookies | Servidor relay → API interna → HLS + Widevine DRM |

---

## Fase 1 — Estabilização dos Embeds (Camada 1)

**Esforço estimado:** 1–2 semanas | **Complexidade:** Baixa

### Estado atual

O `ScreeningBrowserSheet` já implementa a seleção de vídeo por WebView para YouTube, Twitch, Kick, Vimeo, Dailymotion e Google Drive. O `ScreeningPlayerWidget` já renderiza iframes via `InAppWebView`. A sincronização de play/pause/seek existe via Supabase Realtime, mas a injeção de JavaScript no iframe precisa ser aprimorada.

### Ações necessárias

**1.1 — YouTube Iframe API completa**

Atualmente o player injeta JavaScript básico para detectar o estado do player. Precisamos implementar a [YouTube Iframe API](https://developers.google.com/youtube/iframe_api_reference) completa para:

- Detectar eventos `onStateChange` (play, pause, ended, buffering) e propagá-los via Realtime.
- Executar `player.seekTo(seconds)` quando o host faz seek.
- Executar `player.playVideo()` e `player.pauseVideo()` em resposta a eventos Realtime dos outros participantes.

O host envia um evento Realtime com `{ type: 'sync', position: 142.5, is_playing: true }`. Os clientes recebem e executam `evaluateJavascript("player.seekTo(142.5, true); player.playVideo();")` no `InAppWebView`.

**1.2 — Vimeo Player SDK e Dailymotion Player API**

Vimeo e Dailymotion possuem SDKs JavaScript para controle do player embed. Implementar o mesmo padrão de injeção de JS para esses players.

**1.3 — Sincronização de buffer (anti-dessincronização)**

Implementar um mecanismo de re-sincronização periódica: a cada 30 segundos, o host transmite sua posição atual. Se um cliente estiver mais de 3 segundos fora de sincronia, ele faz seek automático. Esse mecanismo já existe no Rave (identificado como `PlaylistStuckException`).

---

## Fase 2 — Player Nativo + HLS Direto (Camada 2)

**Esforço estimado:** 2–3 semanas | **Complexidade:** Média

### Motivação

O iframe embed do Twitch tem latência inerente de 10–30 segundos (HLS padrão) e não permite controle preciso de tempo. O Rave resolve isso extraindo o stream HLS diretamente via API GraphQL da Twitch e tocando com ExoPlayer (Android) / AVPlayer (iOS), que permitem seek frame-a-frame.

### Ações necessárias

**2.1 — Adicionar player nativo ao Flutter**

Adicionar o pacote `media_kit` ao `pubspec.yaml`. Ele fornece um player unificado baseado em `libmpv` (Android/iOS/Desktop) com suporte nativo a HLS, DASH e controle preciso de posição.

```yaml
dependencies:
  media_kit: ^1.1.10
  media_kit_video: ^1.1.10
  media_kit_libs_video: ^1.1.10
```

**2.2 — Refatorar o `ScreeningPlayerWidget` para arquitetura híbrida**

O widget deve decidir dinamicamente qual player usar com base na URL:

```
URL recebida
├── youtube.com / youtu.be / vimeo.com / kick.com / dailymotion.com
│   └── → InAppWebView (iframe embed com JS API)
├── twitch.tv / tubi.tv / pluto.tv / .m3u8 / .mp4
│   └── → media_kit (player nativo HLS)
└── netflix.com / disneyplus.com / primevideo.com (Fase 3)
    └── → media_kit com DRM Widevine
```

Criar um enum `ScreeningPlayerMode { embed, native, drmNative }` e um método `resolvePlayerMode(String url)` no `ScreeningPlayerWidget`.

**2.3 — Serviço Twitch HLS (`TwitchStreamService`)**

Criar `lib/features/live/screening/services/twitch_stream_service.dart` que:

1. Recebe a URL do canal ou VOD (ex: `https://twitch.tv/ninja` ou `https://twitch.tv/videos/123456`).
2. Faz uma requisição POST para `https://gql.twitch.tv/gql` com a query `PlaybackAccessToken_Template` (encontrada nos DEX do Rave):

```graphql
query PlaybackAccessToken_Template(
  $login: String!, $isLive: Boolean!,
  $vodID: ID!, $isVod: Boolean!, $playerType: String!
) {
  streamPlaybackAccessToken(channelName: $login, params: {
    platform: "web", playerBackend: "mediaplayer", playerType: $playerType
  }) @include(if: $isLive) {
    value signature
  }
  videoPlaybackAccessToken(id: $vodID, params: {
    platform: "web", playerBackend: "mediaplayer", playerType: $playerType
  }) @include(if: $isVod) {
    value signature
  }
}
```

3. Com o `value` e `signature` retornados, constrói a URL do manifest HLS:

```
https://usher.twitchapps.com/api/channel/hls/{channel}.m3u8
  ?sig={signature}&token={value}&allow_source=true&allow_spectre=true
```

4. Retorna a URL `.m3u8` para o `ScreeningPlayerWidget`, que a entrega ao `media_kit`.

**2.4 — Integração Tubi e Pluto TV**

O Rave possui `TubiServer.kt` e `PlutoServer.kt` que consomem as APIs públicas dessas plataformas (ambas gratuitas e sem DRM pesado). Mapear os endpoints:

- **Tubi:** `https://tubitv.com/oz/videos/{id}/content` retorna o manifest HLS.
- **Pluto TV:** `https://api.pluto.tv/v2/episodes/{id}/slug` retorna o manifest HLS com segmentos de anúncio que o Rave remove (`removeAdSegments`).

---

## Fase 3 — Servidor Relay e DRM Widevine (Camada 3)

**Esforço estimado:** 4–6 semanas | **Complexidade:** Muito Alta

### Arquitetura do Relay (baseada no `api.red.wemesh.ca`)

O Rave usa um servidor relay centralizado que atua como proxy entre o app e as APIs internas das plataformas de streaming. O NexusHub replicará isso usando **Supabase Edge Functions** (Deno) para as operações de API e um servidor dedicado (ex: Fly.io ou Railway) para o proxy de licença DRM.

O fluxo completo para Netflix é:

```
1. Usuário faz login em netflix.com via ScreeningBrowserSheet
2. App captura cookies: NetflixId + SecureNetflixId
3. App envia cookies + resourceId para Edge Function `netflix-manifest`
4. Edge Function chama Netflix Shakti API:
   POST https://www.netflix.com/nq/msl_v1/cadmium/pbo_manifests/^1.0.0/router
   (com cookies do usuário no header)
5. Edge Function recebe NetflixEdgeManifest (JSON com URLs de segmentos + DRM header)
6. Edge Function retorna ao app: { hls_url, license_url, drm_header }
7. App configura media_kit com DRM Widevine usando license_url
8. Reprodução começa no player nativo
```

### Ações necessárias

**3.1 — Captura de cookies de sessão no `ScreeningBrowserSheet`**

Para Netflix e Disney+, após o login detectado (via URL redirect), extrair os cookies relevantes usando `CookieManager` do `flutter_inappwebview`:

```dart
// Detectar login Netflix
if (url.contains('netflix.com') && !url.contains('/login')) {
  final cookies = await CookieManager.instance()
      .getCookies(url: WebUri('https://www.netflix.com'));
  final netflixId = cookies.firstWhere((c) => c.name == 'NetflixId');
  final secureId = cookies.firstWhere((c) => c.name == 'SecureNetflixId');
  // Enviar para o servidor relay via Edge Function
}
```

**3.2 — Edge Function `screening-netflix-manifest`**

```typescript
// POST /functions/v1/screening-netflix-manifest
// Body: { resourceId: string, netflixId: string, secureNetflixId: string }
// Response: { hlsUrl: string, licenseUrl: string, drmHeader: string }

serve(async (req) => {
  const { resourceId, netflixId, secureNetflixId } = await req.json();

  // Chamar Netflix Shakti API com cookies do usuário
  const manifest = await fetch(
    `https://www.netflix.com/nq/msl_v1/cadmium/pbo_manifests/^1.0.0/router`,
    {
      method: 'POST',
      headers: {
        'Cookie': `NetflixId=${netflixId}; SecureNetflixId=${secureNetflixId}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ movieId: resourceId, ... })
    }
  );

  // Processar NetflixEdgeManifest e retornar dados para o player
  const data = await manifest.json();
  return Response.json({
    hlsUrl: data.videoTracks[0].downloadables[0].urls[0].url,
    licenseUrl: data.links.license.href,
    drmHeader: data.drmHeader,
  });
});
```

**3.3 — Edge Function `screening-disney-manifest`**

Disney+ usa a BAMTech API. O fluxo é similar ao Netflix, mas o Rave detecta o redirect de `/signup` para `/login` como indicador de sessão ativa (`DISNEY_LOGIN_URL = https://www.disneyplus.com/login`).

**3.4 — Edge Function `screening-amazon-manifest`**

Amazon Prime Video usa endpoints regionais (`https://atv-ps.amazon.com`, `https://atv-ps-eu.amazon.co.uk`, etc.). O Rave possui `AmazonServer.kt` com `getManifest()`, `downloadManifest()` e suporte a Widevine (`AmazonDrmCallback`) e ClearKey (`doClearkeyDrm`).

**3.5 — Player com DRM Widevine no Flutter**

O `media_kit` suporta DRM Widevine via configuração de `HttpDataSource` com headers de licença. Implementar um `ScreeningDrmPlayerWidget` que:

1. Recebe `{ hlsUrl, licenseUrl, drmHeader }` do servidor relay.
2. Configura o player com `DrmConfiguration(type: DrmType.widevine, licenseUri: licenseUrl)`.
3. Gerencia a renovação de licença (licenças Widevine expiram, tipicamente em 24h).

**3.6 — Decisão Arquitetural: BYOA (Bring Your Own Account)**

Seguindo o modelo do Rave, **cada participante da sala deve ter sua própria assinatura** do serviço. O NexusHub não distribui o vídeo — apenas sincroniza o `resourceId` e o tempo de reprodução. O servidor relay usa os cookies de **cada usuário individualmente** para buscar o manifest da conta daquele usuário.

Isso é fundamental tanto do ponto de vista técnico (evita um único ponto de falha) quanto legal (o usuário está acessando conteúdo que já pagou).

---

## Fase 4 — Infraestrutura e Segurança

**Esforço estimado:** 1–2 semanas | **Complexidade:** Média

**4.1 — Armazenamento seguro de cookies**

Os cookies de sessão das plataformas de streaming são credenciais sensíveis. Eles **não devem ser armazenados no banco de dados**. Usar o `flutter_secure_storage` para armazenar localmente no dispositivo do usuário e enviá-los apenas nas requisições ao servidor relay (nunca persistir no Supabase).

**4.2 — Rate limiting nas Edge Functions**

Implementar rate limiting nas Edge Functions de manifest para evitar abuso. O padrão já existe nas Edge Functions do NexusHub (ex: `agora-token` usa janela de 60s/10 requisições).

**4.3 — Obfuscação do Client ID da Twitch**

A query GQL da Twitch requer um `Client-ID` no header. Esse valor deve ser armazenado como variável de ambiente no Supabase (`TWITCH_CLIENT_ID`) e não hardcoded no app.

**4.4 — Switchboard (Proxy P2P — Opcional)**

O Rave usa um sistema chamado **Switchboard** (implementado em Rust via UniFFI) que funciona como um proxy P2P para reduzir a latência de sincronização. Ele tem dois modos: `Proxy` (cliente) e `Relay` (servidor). Isso é uma otimização avançada que pode ser considerada em versões futuras do NexusHub.

---

## Fase 5 — Expansão de Plataformas

**Esforço estimado:** Contínuo | **Complexidade:** Variável

Com a infraestrutura das Fases 1–4 em vigor, adicionar novas plataformas torna-se incremental:

| Plataforma | Camada | Trabalho Necessário |
|---|---|---|
| YouTube Music | 1 (Embed) | Adicionar padrão de URL ao `ScreeningBrowserSheet` |
| Twitch Clips | 2 (HLS) | Adicionar suporte a `TwitchClipPlaybackToken` no `TwitchStreamService` |
| Crunchyroll | 3 (Relay) | Edge Function `screening-crunchyroll-manifest` |
| Discovery Max | 3 (Relay) | Edge Function `screening-discomax-manifest` |
| Twitter/X (vídeos) | 2 (HLS) | Extrair URL de vídeo da API pública do Twitter |
| Google Photos | 2 (HLS) | Usar Google Drive API com OAuth do usuário |

---

## Cronograma Consolidado

| Fase | Descrição | Início Sugerido | Duração |
|---|---|---|---|
| **Fase 1** | Estabilização de Embeds (YouTube Iframe API, Vimeo, sincronização) | Semana 1 | 2 semanas |
| **Fase 2** | Player Nativo + Twitch HLS + Tubi/Pluto | Semana 3 | 3 semanas |
| **Fase 3** | Servidor Relay + DRM (Netflix, Disney+, Amazon) | Semana 6 | 6 semanas |
| **Fase 4** | Infraestrutura, segurança e rate limiting | Semana 10 | 2 semanas |
| **Fase 5** | Expansão de plataformas adicionais | Semana 12 | Contínuo |

---

## Riscos e Mitigações

| Risco | Probabilidade | Impacto | Mitigação |
|---|---|---|---|
| Netflix/Disney mudam a API interna (Shakti) | Alta | Alto | Servidor relay modular; atualização sem deploy de app |
| Bloqueio de IP do servidor relay pelas plataformas | Média | Alto | Usar IPs residenciais rotativos (ex: Bright Data) ou CDN com IP diverso |
| Widevine L3 limita resolução a 480p em alguns dispositivos | Alta | Médio | Documentar limitação; oferecer fallback para iframe |
| Twitch muda o `Client-ID` ou o endpoint GQL | Média | Médio | Monitorar o endpoint; manter fallback para iframe embed |
| Violação de TOS das plataformas | Alta | Alto | Modelo BYOA; não distribuir conteúdo, apenas sincronizar posição |

---

## Dependências Técnicas a Adicionar

```yaml
# pubspec.yaml — Flutter
dependencies:
  media_kit: ^1.1.10          # Player nativo HLS/DASH
  media_kit_video: ^1.1.10    # Widget de vídeo para media_kit
  media_kit_libs_video: ^1.1.10 # Bibliotecas nativas (libmpv)
  flutter_secure_storage: ^9.0.0 # Armazenamento seguro de cookies
```

```
# Supabase Edge Functions a criar:
- screening-twitch-manifest    (Fase 2)
- screening-netflix-manifest   (Fase 3)
- screening-disney-manifest    (Fase 3)
- screening-amazon-manifest    (Fase 3)
- screening-hbomax-manifest    (Fase 3)
```

```sql
-- Migration Supabase a criar (Fase 3):
-- Tabela para rastrear quais plataformas cada usuário autorizou
-- (sem armazenar credenciais — apenas flags de autorização)
CREATE TABLE screening_platform_auth (
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  platform TEXT NOT NULL, -- 'netflix', 'disney', 'amazon', etc.
  authorized_at TIMESTAMPTZ DEFAULT NOW(),
  PRIMARY KEY (user_id, platform)
);
```
