-- =============================================================================
-- Migration 236 — Documentos Legais Remotos
--
-- Objetivo: Externalizar Política de Privacidade e Termos de Uso do APK
-- para o banco de dados, permitindo atualizações sem publicar nova versão.
--
-- Estrutura:
--   slug        → identificador único ('privacy_policy', 'terms_of_use')
--   title       → título exibido na tela
--   content_md  → conteúdo em Markdown (renderizado no app com flutter_markdown)
--   version     → versão do documento (ex: '1.0', '1.1')
--   updated_at  → data da última atualização
--
-- RLS: qualquer usuário autenticado pode ler. Apenas platform_admin pode editar.
-- =============================================================================

CREATE TABLE IF NOT EXISTS public.legal_documents (
  slug        TEXT PRIMARY KEY,
  title       TEXT NOT NULL,
  content_md  TEXT NOT NULL DEFAULT '',
  version     TEXT NOT NULL DEFAULT '1.0',
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- RLS
ALTER TABLE public.legal_documents ENABLE ROW LEVEL SECURITY;

-- Qualquer usuário autenticado pode ler
CREATE POLICY "legal_documents_read" ON public.legal_documents
  FOR SELECT TO authenticated
  USING (TRUE);

-- Apenas platform_admin pode criar/editar/deletar
CREATE POLICY "legal_documents_admin_write" ON public.legal_documents
  FOR ALL TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE id = auth.uid() AND is_team_admin = TRUE
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE id = auth.uid() AND is_team_admin = TRUE
    )
  );

-- Trigger para atualizar updated_at automaticamente
CREATE OR REPLACE FUNCTION public.set_legal_documents_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS legal_documents_updated_at ON public.legal_documents;
CREATE TRIGGER legal_documents_updated_at
  BEFORE UPDATE ON public.legal_documents
  FOR EACH ROW EXECUTE FUNCTION public.set_legal_documents_updated_at();

-- =============================================================================
-- Seed: inserir os textos que estavam hardcoded no Flutter
-- =============================================================================

INSERT INTO public.legal_documents (slug, title, version, content_md)
VALUES (
  'privacy_policy',
  'Política de Privacidade',
  '1.0',
  $CONTENT$# Política de Privacidade
**Última atualização:** 29 de março de 2026

Esta Política de Privacidade descreve como o **NexusHub** coleta, usa e protege as informações dos usuários.

---

## 1. Informações que Coletamos

### 1.1 Informações fornecidas por você
- **Dados de conta:** nome de usuário, endereço de e-mail, senha (armazenada com hash seguro), foto de perfil e biografia.
- **Conteúdo gerado:** posts, comentários, mensagens de chat, imagens, vídeos e áudios que você publica ou envia.
- **Informações de perfil:** preferências, interesses e configurações de privacidade.

### 1.2 Informações coletadas automaticamente
- **Dados de uso:** páginas visitadas, funcionalidades utilizadas, tempo de sessão e interações.
- **Dados de dispositivo:** modelo do dispositivo, sistema operacional, identificador único do dispositivo e endereço IP.
- **Dados de localização:** apenas localização aproximada (país/região), nunca localização precisa sem sua permissão explícita.
- **Tokens de push:** para envio de notificações, armazenados de forma segura e vinculados à sua conta.

---

## 2. Como Usamos suas Informações

Utilizamos as informações coletadas para:
- **Fornecer e melhorar o serviço:** personalizar sua experiência, exibir conteúdo relevante e recomendar comunidades.
- **Comunicação:** enviar notificações sobre atividades relevantes (curtidas, comentários, mensagens), atualizações de segurança e novidades do app.
- **Segurança:** detectar e prevenir fraudes, abusos e violações dos Termos de Uso.
- **Análise:** entender como o app é utilizado para melhorar funcionalidades e corrigir problemas.

Não vendemos, alugamos ou compartilhamos suas informações pessoais com terceiros para fins de marketing sem seu consentimento.

---

## 3. Compartilhamento de Informações

Podemos compartilhar suas informações com:
- **Provedores de serviço:** parceiros técnicos que nos ajudam a operar o app (hospedagem, análise, notificações push), sob acordos de confidencialidade.
- **Autoridades legais:** quando exigido por lei, ordem judicial ou para proteger direitos, propriedade ou segurança.
- **Outros usuários:** informações de perfil público (nome de usuário, foto, bio, posts públicos) são visíveis conforme suas configurações de privacidade.

---

## 4. Armazenamento e Segurança

- Seus dados são armazenados em servidores seguros fornecidos pelo **Supabase** (PostgreSQL com criptografia em repouso).
- Senhas são armazenadas usando hashing seguro (bcrypt) e nunca em texto simples.
- Comunicações entre o app e nossos servidores são protegidas por **TLS/HTTPS**.
- Realizamos auditorias de segurança periódicas e aplicamos as melhores práticas do setor.

---

## 5. Seus Direitos

Você tem o direito de:
- **Acessar** suas informações pessoais armazenadas.
- **Corrigir** dados incorretos ou desatualizados.
- **Excluir** sua conta e todos os dados associados (disponível em Configurações > Conta > Excluir Conta).
- **Exportar** seus dados em formato legível (disponível em Configurações > Conta > Exportar Dados).
- **Revogar** consentimentos previamente concedidos.

Para exercer esses direitos, acesse as configurações do app ou entre em contato conosco.

---

## 6. Retenção de Dados

- Dados de conta são retidos enquanto sua conta estiver ativa.
- Após a exclusão da conta, os dados são removidos permanentemente em até **30 dias**, exceto quando exigido por lei.
- Logs de segurança podem ser retidos por até **90 dias**.

---

## 7. Crianças

O NexusHub não é destinado a menores de 13 anos. Não coletamos intencionalmente informações de crianças. Se você acredita que coletamos dados de uma criança, entre em contato conosco imediatamente.

---

## 8. Alterações nesta Política

Podemos atualizar esta Política de Privacidade periodicamente. Notificaremos você sobre mudanças significativas por meio de notificação no app ou e-mail. O uso continuado do app após as alterações constitui aceitação da nova política.

---

## 9. Contato

Se tiver dúvidas sobre esta Política de Privacidade, entre em contato:
- **E-mail:** privacidade@nexushub.app
- **Endereço:** NexusHub, Brasil

---

*Esta política é efetiva a partir de 29 de março de 2026.*$CONTENT$
)
ON CONFLICT (slug) DO UPDATE SET
  title      = EXCLUDED.title,
  version    = EXCLUDED.version,
  content_md = EXCLUDED.content_md;

INSERT INTO public.legal_documents (slug, title, version, content_md)
VALUES (
  'terms_of_use',
  'Termos de Uso',
  '1.0',
  $CONTENT$# Termos de Uso
**Última atualização:** 29 de março de 2026

Bem-vindo ao **NexusHub**! Ao usar nosso aplicativo, você concorda com estes Termos de Uso. Leia-os com atenção.

---

## 1. Aceitação dos Termos

Ao criar uma conta ou usar o NexusHub, você confirma que:
- Tem pelo menos **13 anos** de idade.
- Leu, compreendeu e concorda com estes Termos de Uso e nossa Política de Privacidade.
- Tem capacidade legal para celebrar este contrato.

---

## 2. Sua Conta

### 2.1 Criação de conta
- Você é responsável por manter a confidencialidade de suas credenciais.
- Não compartilhe sua senha com terceiros.
- Notifique-nos imediatamente em caso de uso não autorizado da sua conta.

### 2.2 Precisão das informações
- Você concorda em fornecer informações verdadeiras, precisas e atualizadas.
- Não é permitido criar contas falsas ou se passar por outras pessoas.

---

## 3. Regras de Conduta

Ao usar o NexusHub, você concorda em **não**:
- Publicar conteúdo ilegal, ofensivo, difamatório, obsceno ou que viole direitos de terceiros.
- Assediar, intimidar ou ameaçar outros usuários.
- Fazer spam, phishing ou distribuir malware.
- Tentar acessar sistemas ou dados sem autorização.
- Criar múltiplas contas para contornar banimentos.
- Usar bots ou scripts automatizados sem autorização prévia.
- Vender, transferir ou monetizar sua conta sem nossa aprovação.
- Publicar conteúdo que promova ódio, discriminação ou violência.

---

## 4. Conteúdo do Usuário

### 4.1 Sua propriedade
Você mantém a propriedade do conteúdo que publica. Ao publicar, você nos concede uma licença não exclusiva, mundial e gratuita para exibir, distribuir e promover seu conteúdo dentro do app.

### 4.2 Nossa responsabilidade
Não somos responsáveis pelo conteúdo publicado por usuários. Reservamos o direito de remover qualquer conteúdo que viole estes Termos.

### 4.3 Conteúdo proibido
É estritamente proibido publicar:
- Material sexualmente explícito envolvendo menores.
- Conteúdo que promova terrorismo ou violência extrema.
- Informações pessoais de terceiros sem consentimento (doxxing).
- Conteúdo que viole direitos autorais ou propriedade intelectual.

---

## 5. Comunidades

### 5.1 Regras das comunidades
Cada comunidade pode ter regras adicionais definidas pelos seus líderes. Ao entrar em uma comunidade, você concorda em seguir suas regras específicas.

### 5.2 Moderação
Líderes e curadores de comunidade têm autoridade para moderar conteúdo e usuários dentro de suas comunidades, em conformidade com nossas diretrizes gerais.

---

## 6. Compras e Moedas

### 6.1 Moedas NexusHub
As moedas virtuais do NexusHub não têm valor monetário real e não podem ser trocadas por dinheiro.

### 6.2 Compras in-app
Todas as compras são finais e não reembolsáveis, exceto quando exigido por lei aplicável.

### 6.3 Itens da loja
Itens comprados (stickers, temas, etc.) são licenciados para uso pessoal dentro do app e não podem ser transferidos ou revendidos.

---

## 7. Suspensão e Encerramento

Podemos suspender ou encerrar sua conta se você:
- Violar estes Termos de Uso.
- Criar risco legal para o NexusHub ou outros usuários.
- Ficar inativo por mais de **2 anos** (com aviso prévio por e-mail).

Você pode encerrar sua conta a qualquer momento em Configurações > Conta > Excluir Conta.

---

## 8. Limitação de Responsabilidade

O NexusHub é fornecido "como está", sem garantias de qualquer tipo. Não nos responsabilizamos por:
- Interrupções temporárias do serviço.
- Perda de dados causada por falhas técnicas.
- Danos indiretos ou consequenciais decorrentes do uso do app.

---

## 9. Alterações nos Termos

Podemos modificar estes Termos periodicamente. Notificaremos sobre mudanças significativas com pelo menos **30 dias** de antecedência. O uso continuado após as mudanças constitui aceitação dos novos Termos.

---

## 10. Lei Aplicável

Estes Termos são regidos pelas leis do **Brasil**. Disputas serão resolvidas nos tribunais competentes do Brasil.

---

## 11. Contato

Para dúvidas sobre estes Termos:
- **E-mail:** juridico@nexushub.app
- **Endereço:** NexusHub, Brasil

---

*Estes Termos são efetivos a partir de 29 de março de 2026.*$CONTENT$
)
ON CONFLICT (slug) DO UPDATE SET
  title      = EXCLUDED.title,
  version    = EXCLUDED.version,
  content_md = EXCLUDED.content_md;
