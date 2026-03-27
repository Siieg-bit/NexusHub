# NexusHub — Guia de Configuração Android

## 1. Gerar a estrutura nativa do Flutter

Após clonar o repositório, execute na pasta `frontend/`:

```bash
flutter create . --org com.nexushub --project-name nexushub
```

Isso irá gerar os arquivos nativos restantes (MainActivity, recursos, etc.) sem sobrescrever os que já existem.

## 2. Firebase (Push Notifications + Analytics)

1. Acesse https://console.firebase.google.com
2. Crie um novo projeto ou use um existente
3. Adicione o app Android com package name `com.nexushub.app`
4. Baixe o `google-services.json` e coloque em `android/app/`
5. Execute:

```bash
dart pub global activate flutterfire_cli
flutterfire configure --project=SEU_PROJETO_FIREBASE
```

Isso gera o `firebase_options.dart` automaticamente.

## 3. AdMob (Anúncios Recompensados)

1. Crie uma conta em https://admob.google.com
2. Crie um app e obtenha o App ID
3. Substitua o App ID de teste no `AndroidManifest.xml`:

```xml
<meta-data
    android:name="com.google.android.gms.ads.APPLICATION_ID"
    android:value="SEU_APP_ID_REAL" />
```

4. Atualize os Ad Unit IDs em `lib/core/services/ad_service.dart`

## 4. RevenueCat (Compras In-App)

1. Crie uma conta em https://app.revenuecat.com
2. Configure os produtos no Google Play Console
3. Obtenha a API Key do RevenueCat
4. Atualize a chave em `lib/core/services/iap_service.dart`:

```dart
static const String _apiKeyAndroid = 'SUA_CHAVE_REVENUECAT';
```

## 5. Deep Links

Os deep links já estão configurados no `AndroidManifest.xml` para:

- `nexushub://` — Custom scheme
- `https://nexushub.app/` — App Links (requer verificação de domínio)
- `com.nexushub.app://login-callback` — Callback do Supabase Auth

Para App Links verificados, configure o Digital Asset Links no seu domínio:
`https://nexushub.app/.well-known/assetlinks.json`

## 6. Keystore para Release

```bash
keytool -genkey -v -keystore android/app/keystore/nexushub-release.jks \
  -keyalg RSA -keysize 2048 -validity 10000 -alias nexushub
```

Depois, descomente a seção `signingConfigs.release` no `android/app/build.gradle`.

## 7. Build

```bash
# Debug
flutter run

# Release APK
flutter build apk --release

# Release App Bundle (para Google Play)
flutter build appbundle --release
```
