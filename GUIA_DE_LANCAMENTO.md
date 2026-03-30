# Guia Definitivo de Lançamento: NexusHub 🚀

Este guia foi criado para te orientar do zero até a publicação do seu aplicativo nas lojas (Google Play e App Store). Ele explica exatamente o que você precisa configurar, onde colocar cada chave e como a infraestrutura funciona.

---

## 1. Entendendo a Arquitetura (Onde fica o servidor?)

Você **não precisa alugar um servidor tradicional** (como AWS EC2 ou HostGator) para rodar o NexusHub. O projeto foi construído usando uma arquitetura moderna chamada **Serverless** (Sem Servidor) e **BaaS** (Backend as a Service).

A infraestrutura é dividida em duas partes:

1. **O Backend (Banco de Dados + Autenticação + Funções):** Tudo isso é hospedado no **Supabase**. O Supabase é o seu "servidor". Ele cuida do banco de dados PostgreSQL, do login dos usuários, do armazenamento de imagens (Storage) e das regras de segurança.
2. **O Frontend (O Aplicativo):** É o código em Flutter que vai ser compilado e instalado no celular dos usuários. O aplicativo se conecta diretamente ao Supabase.

> **Resumo:** Você só precisa manter o seu projeto no Supabase ativo. O código fonte (no GitHub) serve apenas para você gerar o aplicativo e fazer atualizações. O GitHub não "roda" o aplicativo.

---

## 2. Configurando os Serviços Externos (API Keys)

O aplicativo usa vários serviços de terceiros para funcionar. Você precisa criar uma conta em cada um deles e pegar as chaves verdadeiras.

### A. Supabase (O Coração do App)
1. Acesse [supabase.com](https://supabase.com) e crie um projeto.
2. Vá em **Project Settings > API Keys**.
3. Você precisará de duas chaves:
   - **Publishable Key** (antiga Anon Key): Segura para colocar no aplicativo.
   - **Secret Key** (antiga Service Role Key): **NUNCA** coloque no aplicativo. Usada apenas para scripts administrativos.

### B. Firebase (Para Notificações Push)
1. Acesse [console.firebase.google.com](https://console.firebase.google.com) e crie um projeto.
2. Adicione um aplicativo Android (com o pacote `com.nexushub.app`).
3. Baixe o arquivo `google-services.json`.
4. Vá em **Configurações do Projeto > Contas de Serviço** e gere uma nova chave privada (um arquivo JSON). Você precisará do conteúdo desse arquivo para o Supabase enviar notificações.

### C. Agora (Para Chamadas de Voz e Vídeo)
1. Acesse [console.agora.io](https://console.agora.io) e crie um projeto.
2. Pegue o **App ID** e o **App Certificate**.

### D. RevenueCat (Para Compras no App / Assinaturas)
1. Acesse [app.revenuecat.com](https://app.revenuecat.com) e crie um projeto.
2. Configure a integração com a Google Play Store e App Store.
3. Pegue a **Public API Key** (Android e iOS).

### E. AdMob (Para Anúncios)
1. Acesse [admob.google.com](https://admob.google.com) e crie um aplicativo.
2. Crie um bloco de anúncio do tipo "Premiado" (Rewarded).
3. Pegue o **App ID** e o **Ad Unit ID**.

### F. Giphy (Para GIFs no Chat)
1. Acesse [developers.giphy.com](https://developers.giphy.com) e crie um app.
2. Pegue a **API Key**.

---

## 3. Onde colocar as chaves?

Agora que você tem todas as chaves, onde elas entram? Elas são divididas em dois lugares: **No Aplicativo** e **No Supabase**.

### Parte 1: No Aplicativo (Frontend)

As chaves públicas devem ser colocadas no arquivo de configuração do Flutter.

1. Abra o arquivo `frontend/lib/config/app_config.dart`.
2. Substitua os valores falsos pelas suas chaves reais:

```dart
// frontend/lib/config/app_config.dart

class AppConfig {
  // ...
  static const String supabaseUrl = 'https://SEU_PROJETO.supabase.co';
  static const String supabaseAnonKey = 'sb_publishable_SUA_CHAVE_AQUI';
  // ...
}
```

*Nota: Para RevenueCat, AdMob, Agora e Giphy, você também precisará atualizar os respectivos arquivos de serviço (`iap_service.dart`, `ad_service.dart`, `call_service.dart`, `giphy_picker.dart`) com as chaves públicas, ou centralizá-las no `app_config.dart` se preferir.*

3. **Firebase:** Pegue o arquivo `google-services.json` que você baixou do Firebase e coloque na pasta `frontend/android/app/`. (Substitua o arquivo `.example` que está lá).

> **Atenção:** O arquivo `app_config.dart` modificado e o `google-services.json` **NÃO DEVEM** ser enviados para o GitHub público. O `.gitignore` já está configurado para proteger o `google-services.json`.

### Parte 2: No Supabase (Edge Functions)

As chaves secretas devem ser configuradas no painel do Supabase, pois elas rodam no servidor e não podem ficar no aplicativo.

1. Vá no painel do Supabase > **Edge Functions** > **Secrets**.
2. Adicione os seguintes secrets:
   - `AGORA_APP_ID`: Seu App ID do Agora.
   - `AGORA_APP_CERTIFICATE`: Seu App Certificate do Agora.
   - `FCM_SERVICE_ACCOUNT_JSON`: O conteúdo completo do JSON da conta de serviço do Firebase.
   - `WEBHOOK_SECRET`: Uma senha forte (ex: gerada com `openssl rand -hex 32`) para proteger a comunicação entre o RevenueCat e o Supabase.

---

## 4. Como gerar o Aplicativo (Build)

Com todas as chaves no lugar, você precisa "compilar" o código para gerar o arquivo instalável.

### Para Android (Gerar o APK ou App Bundle)
Você precisa ter o Flutter e o Android Studio instalados no seu computador.

1. Abra o terminal na pasta `frontend`.
2. Execute o comando para baixar as dependências:
   ```bash
   flutter pub get
   ```
3. Para gerar um APK (para testar no seu celular):
   ```bash
   flutter build apk --release
   ```
   *O arquivo será gerado em `build/app/outputs/flutter-apk/app-release.apk`.*

4. Para gerar um App Bundle (para enviar para a Google Play Store):
   ```bash
   flutter build appbundle --release
   ```
   *O arquivo será gerado em `build/app/outputs/bundle/release/app-release.aab`.*

### Para iOS (Gerar o IPA)
Você **obrigatoriamente** precisa de um computador Mac (macOS) com o Xcode instalado.

1. Abra o terminal na pasta `frontend`.
2. Execute:
   ```bash
   flutter pub get
   cd ios
   pod install
   cd ..
   flutter build ipa --release
   ```

---

## 5. Publicando nas Lojas

### Google Play Store (Android)
1. Crie uma conta de desenvolvedor no [Google Play Console](https://play.google.com/console) (custa uma taxa única de $25).
2. Crie um novo aplicativo.
3. Preencha todas as informações da loja (nome, descrição, prints de tela, política de privacidade).
4. Faça o upload do arquivo `.aab` gerado no passo anterior.
5. Envie para revisão.

### Apple App Store (iOS)
1. Crie uma conta no [Apple Developer Program](https://developer.apple.com/) (custa $99 por ano).
2. Acesse o App Store Connect e crie um novo app.
3. Use o aplicativo **Transporter** (no Mac) ou o próprio Xcode para enviar o arquivo `.ipa` gerado.
4. Preencha as informações da loja e envie para revisão.

---

## Resumo do Fluxo de Trabalho

1. **Código no GitHub:** Fica público para seu portfólio, mas **sem as chaves reais**.
2. **Seu Computador:** Você baixa o código do GitHub, coloca as chaves reais no `app_config.dart` e no `google-services.json`, e gera o aplicativo (`.apk` ou `.aab`).
3. **Supabase:** Fica rodando 24/7 na nuvem, guardando os dados e rodando as funções secretas.
4. **Lojas de App:** Você envia o arquivo gerado no seu computador para o Google e para a Apple.

Se você seguir estes passos, seu aplicativo estará no ar, seguro e funcionando perfeitamente!
