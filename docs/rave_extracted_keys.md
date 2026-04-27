# Keys, Tokens e Endpoints Extraídos do APK do Rave

**Fonte:** Engenharia reversa dos arquivos DEX do Rave (Wemesh Inc.) — `classes1.dex` a `classes12.dex`
**Data da extração:** Abril de 2026
**Uso:** Implementação da Sala de Projeção do NexusHub

> **Aviso:** Este documento é de uso interno e restrito à equipe de desenvolvimento do NexusHub. As keys aqui listadas foram extraídas para fins de interoperabilidade técnica. O NexusHub não distribui conteúdo protegido — apenas sincroniza o estado de reprodução entre usuários que possuem suas próprias assinaturas.

---

## 1. Twitch

O Rave usa dois Client-IDs distintos para a Twitch: um para as queries GQL (player web) e outro registrado no Twitch Developer Console como app próprio.

| Identificador | Valor | Uso |
|---|---|---|
| **GQL Client-ID** (Web) | `kimne78kx3ncx6brgo4mv6wki5h1ko` | Header `Client-ID` nas queries GraphQL para `https://gql.twitch.tv/gql` — é o Client-ID do player web oficial da Twitch |
| **Helix Client-ID** (Rave app) | `rfkghh59eyryzx7wntlgry0mff0yx7z1` | Client-ID registrado pelo Rave no Twitch Developer Console para a API Helix pública |
| **Helix Client-ID** (alternativo) | `d4uvtfdr04uq6raoenvj7m86gdk16v` | Client-ID alternativo (possivelmente ambiente de staging/dev) |

### Endpoints Twitch

```
POST https://gql.twitch.tv/gql
  Header: Client-ID: kimne78kx3ncx6brgo4mv6wki5h1ko
  Body: query PlaybackAccessToken_Template (ver abaixo)

POST https://gql.twitch.tv/integrity
  Header: Client-ID: kimne78kx3ncx6brgo4mv6wki5h1ko
  → Retorna: TwitchIntegrityTokenData { token }
  → O token é necessário para obter o PlaybackAccessToken
```

### Query GQL para PlaybackAccessToken

```graphql
query PlaybackAccessToken_Template(
  $login: String!, $isLive: Boolean!,
  $vodID: ID!, $isVod: Boolean!, $playerType: String!
) {
  streamPlaybackAccessToken(channelName: $login, params: {
    platform: "web", playerBackend: "mediaplayer", playerType: $playerType
  }) @include(if: $isLive) {
    value
    signature
  }
  videoPlaybackAccessToken(id: $vodID, params: {
    platform: "web", playerBackend: "mediaplayer", playerType: $playerType
  }) @include(if: $isVod) {
    value
    signature
  }
}
```

### Construção da URL HLS

Com o `value` e `signature` retornados pela query:

```
# Para canal ao vivo:
https://usher.twitchapps.com/api/channel/hls/{channel}.m3u8
  ?sig={signature}
  &token={value}
  &allow_source=true
  &allow_spectre=true

# Para VOD:
https://usher.twitchapps.com/vod/{vodId}.m3u8
  ?sig={signature}
  &token={value}
  &allow_source=true
```

**Recomendação para NexusHub:** usar `kimne78kx3ncx6brgo4mv6wki5h1ko` (GQL Web) — é o mesmo que o player web da Twitch usa, portanto não levanta suspeitas e é menos propenso a ser revogado.

---

## 2. YouTube (Innertube API)

O Rave implementa um cliente Innertube completo (`InnertubeClient.kt`) com suporte a Web, Mweb e Android. As keys abaixo são usadas para acessar a API interna do YouTube sem passar pelo iframe.

| Identificador | Valor | Uso |
|---|---|---|
| **Web API key** | `AIzaSyAO_FJ2SlqU8Q4STEHLGCilw_Y9_11qcW8` | Browse, search, live chat, updated_metadata |
| **Player API key** | `AIzaSyA8eiZmM1FaDVjRy-df2KTyQ_vz_yYM39w` | `youtubei.googleapis.com/youtubei/v1/player` — retorna streams HLS/DASH |
| **Music API key** | `AIzaSyATBXajvzQLTDHEQbcpq0Ihe0vWDHmO520` | YouTube Music |
| **Google Drive playback** | `AIzaSyDVQw45DwoYh632gvsP5vPDqEKvb-Ywnb8` | `/playback?key=` para arquivos do Google Drive |

### Endpoints YouTube Innertube

```
# Player (retorna streams HLS/DASH do vídeo):
POST https://youtubei.googleapis.com/youtubei/v1/player?key=AIzaSyA8eiZmM1FaDVjRy-df2KTyQ_vz_yYM39w&prettyPrint=false

# Browse (página de vídeo, playlists):
POST https://www.youtube.com/youtubei/v1/browse?key=AIzaSyAO_FJ2SlqU8Q4STEHLGCilw_Y9_11qcW8&prettyPrint=false

# Search:
POST https://www.youtube.com/youtubei/v1/search?key=AIzaSyAO_FJ2SlqU8Q4STEHLGCilw_Y9_11qcW8&prettyPrint=false

# Live chat:
POST https://www.youtube.com/youtubei/v1/live_chat/get_live_chat?key=AIzaSyAO_FJ2SlqU8Q4STEHLGCilw_Y9_11qcW8&prettyPrint=false

# Google Drive playback:
GET https://www.googleapis.com/drive/v3/files/{fileId}/playback?key=AIzaSyDVQw45DwoYh632gvsP5vPDqEKvb-Ywnb8
```

**Recomendação para NexusHub:** o **Player API key** é o mais valioso — permite extrair o stream HLS/DASH do YouTube nativamente, sem depender do iframe, possibilitando sincronização de tempo muito mais precisa.

---

## 3. Tubi

O Tubi é um serviço gratuito (AVOD) sem DRM pesado. O Rave usa um HMAC key para assinar as requisições ao endpoint de conteúdo.

| Identificador | Valor |
|---|---|
| **HMAC key** | `jjLuguQ1TtUBIYvLkWHGRHLEQB49t1f8VaYjdD5pX6Q=` |

### Endpoints Tubi

```
# Conteúdo do vídeo (retorna manifest HLS):
GET https://tubitv.com/oz/videos/{id}/content
  ?video_resources=hlsv6_widevine_psshv0
  &video_resources=hlsv3

# Vídeos relacionados:
GET https://tubitv.com/oz/videos/{id}/related
```

O HMAC key é usado para assinar o timestamp da requisição no header `X-Tubi-Signature` (ou similar). Sem a assinatura, o endpoint retorna 403.

---

## 4. Pluto TV

O Pluto TV é gratuito e usa um `client_id` fixo para identificar o app no boot endpoint. Não requer login.

| Identificador | Valor |
|---|---|
| **client_id** | `b6746ddc-7bc7-471f-a16c-f6aaf0c34d26` |

### Endpoints Pluto TV

```
# Boot (sessão anônima + lista de canais/categorias):
GET https://boot.pluto.tv/v4/start
  ?appName=web
  &appVersion=7.0.0
  &deviceVersion=1.0.0
  &deviceModel=web
  &deviceMake=web
  &deviceType=web
  &clientID=b6746ddc-7bc7-471f-a16c-f6aaf0c34d26
  &clientModelNumber=1.0.0
  &serverSideAds=false

# VOD items (retorna metadados e URL do stream):
GET https://service-vod.clusters.pluto.tv/v4/vod/items?ids={id}

# VOD séries:
GET https://service-vod.clusters.pluto.tv/v4/vod/series/{seriesId}

# Canais ao vivo:
GET https://service-channels.clusters.pluto.tv/v2/guide/channels?channelIds={id}

# Categorias:
GET https://service-media-catalog.clusters.pluto.tv/v1/main-categories
```

**Nota:** O Rave implementa `removeAdSegments` para remover os segmentos de anúncio do manifest HLS do Pluto TV antes de entregar ao player.

---

## 5. Crunchyroll

O Crunchyroll usa OAuth2 com Basic auth. O `client_id` e `client_secret` são gerados dinamicamente em runtime pelo método `getBasicAuthToken` — não estão hardcoded nos DEX (provavelmente obtidos via Firebase Remote Config).

### Endpoints Crunchyroll

```
# Autenticação (OAuth2 com Basic auth):
POST https://www.crunchyroll.com/auth/v1/token
  Header: Authorization: Basic {base64(client_id:client_secret)}
  Body: grant_type=client_credentials

# Playback token (retorna URL do stream):
GET https://www.crunchyroll.com/playback/v1/token/{episodeId}

# Playback v2:
GET https://www.crunchyroll.com/playback/v2/{episodeId}

# Licença Widevine:
POST https://www.crunchyroll.com/license/v1/license/widevine

# Conteúdo:
GET https://www.crunchyroll.com/content/v2/cms/series/{seriesId}
GET https://www.crunchyroll.com/content/v2/cms/seasons/{seasonId}
GET https://www.crunchyroll.com/content/v2/cms/objects/{objectId}

# Login:
https://sso.crunchyroll.com/register
https://www.crunchyroll.com/account/membership
```

---

## 6. VK

| Identificador | Valor | Uso |
|---|---|---|
| **client_id** | `7879029` | `https://api.vk.ru/method/video.getVideoDiscover?v=5.245&client_id=7879029` |
| **VKIDClientID** | Valor em runtime | SDK VK ID para autenticação OAuth |
| **VKIDClientSecret** | Valor em runtime | SDK VK ID para autenticação OAuth |

### Endpoints VK

```
GET https://api.vk.ru/method/video.getVideoDiscover?v=5.245&client_id=7879029
GET https://api.vk.ru (base URL)
```

---

## 7. Plataformas com Servidor Relay (DRM)

As plataformas abaixo **não possuem keys hardcoded** no APK. O Rave usa seu servidor relay `https://api.red.wemesh.ca/` como intermediário, que faz as requisições para as APIs internas usando os cookies de sessão de cada usuário. O NexusHub precisará implementar um servidor relay equivalente.

### 7.1 Infraestrutura do Relay Rave

```
Servidor principal:   https://api.red.wemesh.ca/
CDN (Fastly):         wallace.prod.wemesh.ca.global.prod.fastly.net
Fallback:             api.red.wemesh.ca → api1.a-l-p-a.com
Events:               https://events.api.red.wemesh.ca/
DMS (mensagens):      https://wallace2.{env}.wemesh.ca/
Switchboard (P2P):    SWITCHBOARD_API_URL_DEFAULT / SWITCHBOARD_HOST_DEFAULT
                      (valores obtidos via Firebase Remote Config)
```

O **Switchboard** é um proxy P2P implementado em Rust (via UniFFI) com dois modos: `Proxy` (cliente) e `Relay` (servidor). Ele reduz a latência de sincronização ao criar um canal direto entre os participantes da sala.

### 7.2 Netflix

**Fluxo de autenticação:**
1. Usuário faz login em `https://netflix.com/login` via WebView
2. App detecta os cookies `NetflixId` e `SecureNetflixId` via `NetflixWebkitCookieManagerProxy`
3. Cookies são enviados ao servidor relay

**Endpoints Netflix (chamados pelo relay com cookies do usuário):**

```
# Manifest de vídeo (MSL Protocol):
POST https://www.netflix.com/nq/msl_v1/cadmium/pbo_manifests/^1.0.0/router
  Cookie: NetflixId={id}; SecureNetflixId={secureId}
  → Retorna: NetflixEdgeManifest com URLs de segmentos HLS + DRM header

# Licença DRM:
POST https://www.netflix.com/nq/msl_v1/cadmium/pbo_licenses/^1.0.0/router
  Cookie: NetflixId={id}; SecureNetflixId={secureId}

# Metadados do título:
GET https://www.netflix.com/nq/website/memberapi/release/metadata
  ?movieid={id}&imageFormat=webp&withSize=true&materialize=true

# Página do título:
https://www.netflix.com/title/{id}
https://www.netflix.com/watch/{id}
```

**Cookies capturados:**

| Cookie | Descrição |
|---|---|
| `NetflixId` | Identificador de sessão principal |
| `SecureNetflixId` | Identificador de sessão seguro (HTTPS only) |
| `NetflixIdEdge` | Variante edge do NetflixId |
| `SecureNetflixIdEdge` | Variante edge do SecureNetflixId |

### 7.3 Disney+

**Fluxo de autenticação:**
1. Usuário faz login em `https://www.disneyplus.com/login` via WebView
2. App detecta o redirect pós-login e captura os tokens de sessão

**Endpoints Disney+ (chamados pelo relay):**

```
# Configuração do SDK BAM:
GET https://bam-sdk-configs.bamgrid.com/bam-sdk/v4.0/disney-svod-3d9324fc/android/v8.3.0/google/handset/prod.json
  → Retorna URLs dinâmicas de autenticação e playback

# Playback (retorna manifest HLS + DRM):
POST https://disney.playback.edge.bamgrid.com/v7/playback/ctr-regular
  Header: Authorization: Bearer {userToken}
  Body: { "playback": { "attributes": { "resolution": { "max": ["1920x1080"] } } } }

# Exploração de conteúdo:
GET https://disney.api.edge.bamgrid.com/explore/v1.2
GET https://disney.api.edge.bamgrid.com/explore/v1.4/page/{pageId}
GET https://disney.api.edge.bamgrid.com/explore/v1.3/season/{seasonId}
GET https://disney.api.edge.bamgrid.com/explore/v1.2/playerExperience/{contentId}

# Imagens:
GET https://disney.images.edge.bamgrid.com/ripcut-delivery/v1/variant/disney/{imageId}
```

**client_id Disney+:** `disney-svod-3d9324fc` (identificador do app Rave no ecossistema BAMTech)

### 7.4 Amazon Prime Video

**Fluxo de autenticação:**
1. Usuário faz login em `https://primevideo.com` via WebView
2. App captura cookies de sessão da Amazon

**Endpoints Amazon (chamados pelo relay com cookies do usuário):**

```
# Startup config (obtém endpoints regionais):
GET https://na.api.amazonvideo.com/cdp/usage/v2/GetAppStartupConfig
  ?deviceTypeID=A28RQHJKHM2A2W
  &deviceID={deviceId}
  &firmware=1&version=1&format=json

# Manifest (DASH/HLS):
GET {regionalHost}/cdp/catalog/GetPlaybackResources
  → Retorna: amazon_dash_manifest.xml + URLs de licença DRM

# Hosts regionais:
  https://atv-ps.amazon.com          (América do Norte)
  https://atv-ps.primevideo.com      (América do Norte - alt)
  https://atv-ps-eu.amazon.co.uk     (Europa - UK)
  https://atv-ps-eu.amazon.de        (Europa - Alemanha)
  https://atv-ps-eu.primevideo.com   (Europa - alt)
  https://atv-ps-fe.amazon.co.jp     (Ásia - Japão)
  https://atv-ps-fe.primevideo.com   (Ásia - alt)
```

**deviceTypeID Amazon:** `A28RQHJKHM2A2W` (identificador do dispositivo Rave no sistema Amazon)

**Nota:** O Rave suporta dois tipos de DRM para Amazon: Widevine (`AmazonDrmCallback`) e ClearKey (`doClearkeyDrm`).

### 7.5 HBO Max / Max

**Fluxo de autenticação:**
1. Usuário faz login em `https://play.max.com` via WebView
2. App captura tokens de sessão

**Endpoints Max (chamados pelo relay):**

```
# Playback info (retorna manifest HLS + DRM):
POST https://default.any-any.prd.api.max.com/any/playback/v1/playbackInfo
  Header: Authorization: Bearer {userToken}

# Conteúdo:
GET https://default.prd.api.max.com/content/videos/{videoId}
GET https://default.prd.api.max.com/cms/routes/movie/{movieId}
GET https://default.prd.api.max.com/cms/recommendations/nextVideos?videoId={id}
GET https://default.prd.api.discomax.com/cms/routes/video/watch/{videoId}

# URLs de acesso:
https://play.max.com/video/watch/{id}
https://play.max.com/movie/{id}
https://play.max.com/show/{id}
https://play.hbomax.com/video/{id}  (legado)
```

---

## 8. Firebase do Rave (Referência)

Estas keys pertencem ao projeto Firebase do Rave e **não devem ser usadas** no NexusHub. Estão listadas apenas para referência.

| Identificador | Valor |
|---|---|
| Dynamic Links key | `AIzaSyBCVlPRwGjpgmzYnVWDRWqaPMLS9LJ0mFU` |
| Backup key | `AIzaSyCxkwf_tPAdJA-oyrre4pv6oC8jgo-fGKo` |
| Firebase Dynamic Links URL | `https://firebasedynamiclinks.googleapis.com/v1/shortLinks?key=AIzaSyBCVlPRwGjpgmzYnVWDRWqaPMLS9LJ0mFU` |

---

## 9. Resumo: Prioridade de Implementação no NexusHub

| Prioridade | Plataforma | Key/Token | Complexidade | Valor |
|---|---|---|---|---|
| **1** | Twitch | `kimne78kx3ncx6brgo4mv6wki5h1ko` (GQL) | Média | HLS direto, sincronização precisa |
| **2** | Tubi | `jjLuguQ1TtUBIYvLkWHGRHLEQB49t1f8VaYjdD5pX6Q=` | Baixa | Conteúdo gratuito sem login |
| **3** | Pluto TV | `b6746ddc-7bc7-471f-a16c-f6aaf0c34d26` | Baixa | Conteúdo gratuito sem login |
| **4** | YouTube | `AIzaSyA8eiZmM1FaDVjRy-df2KTyQ_vz_yYM39w` (Player) | Média | Player nativo sem iframe |
| **5** | Netflix | Relay + cookies do usuário | Muito Alta | Maior base de usuários |
| **6** | Disney+ | Relay + BAM token | Muito Alta | Segunda maior base |
| **7** | Amazon Prime | Relay + cookies + deviceTypeID | Alta | Terceira maior base |
| **8** | HBO Max | Relay + token | Alta | Nicho premium |
| **9** | Crunchyroll | OAuth2 dinâmico | Alta | Nicho anime |
| **10** | VK | `client_id=7879029` | Baixa | Mercado russo |
