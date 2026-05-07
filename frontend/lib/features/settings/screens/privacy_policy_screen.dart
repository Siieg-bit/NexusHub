import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/l10n/locale_provider.dart';
import 'package:amino_clone/config/nexus_theme_extension.dart';

// =============================================================================
// PrivacyPolicyScreen — Política de Privacidade
//
// O conteúdo é carregado remotamente da tabela `legal_documents` (slug:
// 'privacy_policy'), eliminando o texto hardcoded anterior.
// =============================================================================

/// Provider que busca a Política de Privacidade do Supabase.
final _privacyPolicyProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final rows = await SupabaseService.table('legal_documents')
      .select('title, content_md, version, updated_at')
      .eq('slug', 'privacy_policy')
      .limit(1);
  if ((rows as List).isEmpty) throw Exception('Documento não encontrado.');
  return rows.first as Map<String, dynamic>;
});

class PrivacyPolicyScreen extends ConsumerWidget {
  const PrivacyPolicyScreen({super.key});

  // Conteúdo de fallback exibido apenas se o banco estiver inacessível.
  // Será removido em versões futuras quando o app exigir conexão.
  static const _fallbackContent = '''
# Política de Privacidade

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

*Esta política é efetiva a partir de 29 de março de 2026.*
''';

  MarkdownStyleSheet _markdownStyle(BuildContext context, Responsive r) {
    final theme = context.nexusTheme;
    return MarkdownStyleSheet(
      h1: TextStyle(
          color: theme.textPrimary, fontSize: r.fs(22),
          fontWeight: FontWeight.w800, fontFamily: 'PlusJakartaSans'),
      h2: TextStyle(
          color: theme.textPrimary, fontSize: r.fs(17),
          fontWeight: FontWeight.w700, fontFamily: 'PlusJakartaSans'),
      h3: TextStyle(
          color: theme.textPrimary, fontSize: r.fs(15),
          fontWeight: FontWeight.w600, fontFamily: 'PlusJakartaSans'),
      p: TextStyle(
          color: theme.textSecondary, fontSize: r.fs(14),
          height: 1.6, fontFamily: 'PlusJakartaSans'),
      strong: TextStyle(
          color: theme.textPrimary, fontWeight: FontWeight.w700,
          fontFamily: 'PlusJakartaSans'),
      listBullet: TextStyle(color: theme.accentPrimary, fontSize: r.fs(14)),
      horizontalRuleDecoration: BoxDecoration(
        border: Border(top: BorderSide(color: theme.divider, width: 1)),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = context.nexusTheme;
    final r = context.r;
    final s = ref.watch(stringsProvider);
    final docAsync = ref.watch(_privacyPolicyProvider);

    return Scaffold(
      backgroundColor: theme.backgroundPrimary,
      appBar: AppBar(
        backgroundColor: theme.appBarBackground,
        foregroundColor: theme.appBarForeground,
        elevation: 0,
        centerTitle: true,
        surfaceTintColor: Colors.transparent,
        title: Text(
          s.privacyPolicyTitle,
          style: TextStyle(
            color: theme.appBarForeground,
            fontSize: r.fs(18),
            fontWeight: FontWeight.w700,
            fontFamily: 'PlusJakartaSans',
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded,
              color: theme.appBarForeground, size: r.s(20)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 0.5, color: theme.divider),
        ),
      ),
      body: docAsync.when(
        loading: () => Center(
          child: CircularProgressIndicator(
              color: theme.accentPrimary, strokeWidth: 2)),
        error: (_, __) => Markdown(
          data: _fallbackContent,
          padding: EdgeInsets.all(r.s(16)),
          styleSheet: _markdownStyle(context, r),
        ),
        data: (doc) {
          final content = doc['content_md'] as String? ?? _fallbackContent;
          final version = doc['version'] as String? ?? '1.0';
          return Column(
            children: [
              Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(
                    horizontal: r.s(16), vertical: r.s(8)),
                color: theme.surfacePrimary,
                child: Text(
                  'Versão $version',
                  style: TextStyle(
                    color: theme.textSecondary,
                    fontSize: r.fs(12),
                    fontFamily: 'PlusJakartaSans',
                  ),
                ),
              ),
              Expanded(
                child: Markdown(
                  data: content,
                  padding: EdgeInsets.all(r.s(16)),
                  styleSheet: _markdownStyle(context, r),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
