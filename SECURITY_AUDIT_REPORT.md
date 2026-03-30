# Relatório de Auditoria de Segurança - NexusHub

Este relatório apresenta os resultados da auditoria de segurança realizada no projeto NexusHub antes de sua publicação no GitHub. Foram identificadas diversas exposições de dados sensíveis e vulnerabilidades arquiteturais que precisam ser corrigidas.

---

## 1. Dados Sensíveis e Variáveis Hardcoded

### 🔴 Risco Alto: Chaves de API e Credenciais no Código
Foram encontradas várias chaves de produção e tokens hardcoded diretamente no código-fonte:

1. **Supabase (URL e Anon Key)**
   - **Onde:** `frontend/lib/config/app_config.dart` (linhas 11-15)
   - **Onde:** Fallbacks em múltiplas Edge Functions (`agora-token`, `check-in`, `delete-user-data`, `export-user-data`, `moderation`, `push-notification`, `webhook-handler`).
   - **Impacto:** Permite que qualquer pessoa acesse o banco de dados usando a Anon Key.

2. **Agora RTC (App ID e Certificate)**
   - **Onde:** `frontend/lib/core/services/call_service.dart` (linha 87)
   - **Onde:** `backend/supabase/functions/agora-token/index.ts` (linhas 22-23)
   - **Impacto:** O App Certificate é um segredo de servidor. Sua exposição permite que terceiros gerem tokens válidos e utilizem sua cota do Agora gratuitamente.

3. **RevenueCat (API Key)**
   - **Onde:** `frontend/lib/core/services/iap_service.dart` (linha 11: `SUA_REVENUECAT_KEY_AQUI`)
   - **Impacto:** Exposição da chave de testes de pagamentos in-app.

4. **Giphy (API Key)**
   - **Onde:** `frontend/lib/features/chat/widgets/giphy_picker.dart` (linha 55: `SUA_GIPHY_API_KEY_AQUI`)
   - **Impacto:** Uso não autorizado da cota da API do Giphy.

5. **AdMob (App ID e Ad Unit IDs)**
   - **Onde:** `frontend/lib/core/services/ad_service.dart` e `AndroidManifest.xml`
   - **Impacto:** Risco de tráfego inválido e banimento da conta AdMob.

---

## 2. Exposição no Histórico do Git

### 🔴 Risco Alto: Commits com Dados Sensíveis
Mesmo que você remova as chaves do código atual, **elas já estão salvas no histórico do Git**.
- O commit `afe884f` introduziu a chave real do Supabase.
- O commit `537062f` introduziu o App Certificate do Agora.
- Qualquer pessoa que clonar o repositório público poderá navegar pelo histórico e extrair essas chaves.

### 🟡 Risco Médio: Arquivos de Configuração Rastreados
- **`google-services.json`:** O arquivo está sendo rastreado pelo Git (`frontend/android/app/google-services.json`). Embora atualmente contenha placeholders, é uma prática perigosa, pois um desenvolvedor pode acidentalmente commitar o arquivo real de produção.
- **Arquivos `.temp` do Supabase:** O diretório `backend/supabase/.temp/` e `backend/supabase/supabase/.temp/` estão sendo commitados. Eles vazam informações da infraestrutura, como a URL do pooler do banco de dados (`postgresql://postgres.SEU_PROJECT_REF@aws-1-us-east-1.pooler.supabase.com:5432/postgres`).

---

## 3. Vulnerabilidades Arquiteturais e de Configuração

### 🟡 Risco Médio: Segurança das Edge Functions
1. **Falta de Validação de Assinatura (Webhook):** A função `webhook-handler` não verifica o cabeçalho `x-webhook-signature`. Qualquer pessoa que descobrir a URL da função pode enviar requisições POST forjadas, manipulando contadores ou disparando notificações falsas.
2. **CORS Muito Permissivo:** Todas as Edge Functions estão configuradas com `Access-Control-Allow-Origin: "*"`. Isso permite que qualquer site malicioso faça requisições para suas funções diretamente do navegador do usuário.

### 🟡 Risco Médio: Políticas RLS (Row Level Security)
- **Políticas de Leitura Públicas:** Várias tabelas (ex: `achievements`, `stories`, `call_sessions`) possuem políticas `FOR SELECT USING (true)`. Isso significa que qualquer pessoa com a Anon Key (que é pública por design) pode ler todos os dados dessas tabelas, mesmo sem estar autenticada. Recomenda-se usar `auth.role() = 'authenticated'` para dados que exigem login.

---

## 🛠️ Recomendações Práticas de Correção

### Passo 1: Limpar o Histórico do Git (CRÍTICO)
Antes de tornar o repositório público, você **deve** reescrever o histórico para remover as chaves antigas.
**Opção A (Mais fácil):** Fazer um "squash" de todos os commits em um único commit inicial (após remover as chaves do código).
**Opção B (Mantém histórico):** Usar a ferramenta [BFG Repo-Cleaner](https://rtyley.github.io/bfg-repo-cleaner/) ou `git filter-repo` para expurgar as strings sensíveis de todo o histórico.

### Passo 2: Migrar Variáveis para o `.env` no Flutter
1. Adicione o pacote `flutter_dotenv` ao `pubspec.yaml`.
2. Crie um arquivo `.env` na raiz do `frontend/` e adicione-o ao `.gitignore`.
3. Substitua as chaves no `app_config.dart`, `call_service.dart`, etc., por chamadas ao dotenv:
   ```dart
   static String get supabaseUrl => dotenv.env['SUPABASE_URL'] ?? '';
   ```
*(Alternativa: usar `--dart-define` no momento do build).*

### Passo 3: Proteger as Edge Functions
1. **Remover Fallbacks:** No código TypeScript, remova os valores hardcoded após o `??`. Use apenas `Deno.env.get("VAR_NAME")`.
2. **Supabase Secrets:** Configure as variáveis no painel do Supabase ou via CLI:
   ```bash
   supabase secrets set AGORA_APP_ID=seu_id AGORA_APP_CERT=seu_cert
   ```
3. **Validar Webhooks:** Atualize o `webhook-handler` para usar a biblioteca de crypto do Supabase e validar o HMAC do payload usando o `WEBHOOK_SECRET`.

### Passo 4: Atualizar o `.gitignore`
Adicione as seguintes linhas ao `.gitignore` na raiz do projeto:
```text
# Chaves e Configurações
.env
frontend/.env
frontend/android/app/google-services.json
frontend/ios/GoogleService-Info.plist
frontend/lib/firebase_options.dart

# Keystores
*.jks
*.keystore
key.properties

# Supabase Temp
backend/supabase/.temp/
backend/supabase/supabase/.temp/
```
Após adicionar, remova os arquivos cacheados do git:
```bash
git rm -r --cached backend/supabase/.temp/
git rm --cached frontend/android/app/google-services.json
```

### Passo 5: Rotacionar as Chaves (Revogação)
Como as chaves já foram commitadas localmente (e possivelmente em repositórios privados), a prática mais segura é **gerar novas chaves** nos painéis do Supabase, Agora e RevenueCat após a limpeza do repositório.
