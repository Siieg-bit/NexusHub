# Guia de Configuração do Shorebird OTA — NexusHub

**Objetivo:** Permitir que a equipe envie atualizações de código Dart diretamente para os dispositivos dos usuários sem passar pela revisão das lojas (Play Store / App Store).

---

## 1. Instalação do Shorebird CLI (na máquina de desenvolvimento)

```bash
# Instalar o Shorebird CLI
curl --proto '=https' --tlsv1.2 https://raw.githubusercontent.com/shorebirdtech/install/main/install.sh -sSf | bash

# Verificar instalação
shorebird --version

# Fazer login (cria conta em https://console.shorebird.dev)
shorebird login
```

---

## 2. Inicialização no Projeto Flutter

```bash
# Navegar para o frontend
cd frontend/

# Inicializar o Shorebird no projeto
# Isso adiciona shorebird.yaml e modifica o AndroidManifest.xml
shorebird init

# Verificar o arquivo gerado
cat shorebird.yaml
```

O arquivo `shorebird.yaml` gerado terá este formato:
```yaml
app_id: <SEU_APP_ID_AQUI>
```

---

## 3. Adicionar o shorebird_code_push ao pubspec.yaml

```bash
# Adicionar o pacote para ler a versão do patch em runtime (opcional)
flutter pub add shorebird_code_push
```

---

## 4. Primeiro Release (substitui o flutter build)

```bash
# Em vez de: flutter build apk --release
# Usar:
shorebird release android

# Para iOS (quando disponível):
shorebird release ios
```

---

## 5. Enviar um Patch (hotfix sem atualizar nas lojas)

```bash
# Após corrigir um bug ou fazer uma mudança de UI:
shorebird patch android

# O patch é aplicado automaticamente na próxima inicialização do app
# pelos usuários que já têm o release instalado
```

---

## 6. Workflow GitHub Actions (CI/CD)

Criar o arquivo `.github/workflows/shorebird.yml`:

```yaml
name: Shorebird — Release & Patch

on:
  push:
    branches:
      - main
    tags:
      - 'v*'

jobs:
  # ── PATCH: enviado a cada push na main (hotfixes automáticos) ──────────────
  patch:
    name: Shorebird Patch (Android)
    runs-on: ubuntu-latest
    if: github.ref == 'refs/heads/main' && !startsWith(github.ref, 'refs/tags/')
    steps:
      - uses: actions/checkout@v4

      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.32.x'
          channel: 'stable'

      - uses: shorebirdtech/setup-shorebird@v1
        with:
          token: ${{ secrets.SHOREBIRD_TOKEN }}

      - name: Instalar dependências
        working-directory: frontend
        run: flutter pub get

      - name: Enviar patch Android
        working-directory: frontend
        run: shorebird patch android --release-version=${{ github.sha }}

  # ── RELEASE: criado apenas quando uma tag vX.Y.Z é publicada ──────────────
  release:
    name: Shorebird Release (Android)
    runs-on: ubuntu-latest
    if: startsWith(github.ref, 'refs/tags/v')
    steps:
      - uses: actions/checkout@v4

      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.32.x'
          channel: 'stable'

      - uses: shorebirdtech/setup-shorebird@v1
        with:
          token: ${{ secrets.SHOREBIRD_TOKEN }}

      - name: Instalar dependências
        working-directory: frontend
        run: flutter pub get

      - name: Criar release Android
        working-directory: frontend
        run: shorebird release android

      - name: Upload APK como artefato
        uses: actions/upload-artifact@v4
        with:
          name: nexushub-release-${{ github.ref_name }}
          path: frontend/build/app/outputs/flutter-apk/app-release.apk
```

---

## 7. Configurar o Secret no GitHub

1. Acessar: `https://github.com/Siieg-bit/NexusHub/settings/secrets/actions`
2. Criar novo secret: `SHOREBIRD_TOKEN`
3. Valor: obtido com `shorebird login:ci` na máquina de desenvolvimento

---

## 8. Fluxo de Trabalho Recomendado

| Situação | Ação | Comando |
|---|---|---|
| Bug crítico em produção | Hotfix imediato | `shorebird patch android` |
| Nova feature (sem código nativo) | Patch frequente | `shorebird patch android` |
| Nova feature (com SDK nativo) | Release nas lojas | `git tag v1.x.x && git push --tags` |
| Mudança no AndroidManifest | Release nas lojas | `git tag v1.x.x && git push --tags` |
| Mudança de permissão Android | Release nas lojas | `git tag v1.x.x && git push --tags` |

---

## 9. O que o Shorebird PODE atualizar via OTA

- Qualquer código Dart (lógica, UI, providers, services)
- Assets bundlados (imagens, fontes) — com flag `--asset-changes`
- Correções de bugs em qualquer tela
- Novos widgets e telas que usam APIs existentes

## 10. O que o Shorebird NÃO PODE atualizar via OTA

- Código nativo Kotlin/Swift (ex: plugins, SDKs)
- `AndroidManifest.xml` (permissões, deep links)
- `build.gradle` (dependências nativas)
- SDKs nativos (Agora RTC, Firebase, AdMob, RevenueCat)
- Mudanças na versão mínima do Android/iOS

---

## 11. Verificar Status do Shorebird

```bash
# Ver todos os releases e patches
shorebird releases list

# Ver detalhes de um release específico
shorebird releases list --app-id <APP_ID>
```

---

**Referências:**
- Documentação oficial: https://docs.shorebird.dev
- Console: https://console.shorebird.dev
- FAQ: https://docs.shorebird.dev/code-push/faq/
