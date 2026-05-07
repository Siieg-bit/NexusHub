import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/l10n/locale_provider.dart';
import 'package:amino_clone/config/nexus_theme_extension.dart';

// =============================================================================
// TermsOfUseScreen — Termos de Uso
//
// O conteúdo é carregado remotamente da tabela `legal_documents` (slug:
// 'terms_of_use'), eliminando o texto hardcoded anterior.
// =============================================================================

/// Provider que busca os Termos de Uso do Supabase.
final _termsOfUseProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final rows = await SupabaseService.table('legal_documents')
      .select('title, content_md, version, updated_at')
      .eq('slug', 'terms_of_use')
      .limit(1);
  if ((rows as List).isEmpty) throw Exception('Documento não encontrado.');
  return rows.first as Map<String, dynamic>;
});

/// Tela de Termos de Uso do NexusHub.
class TermsOfUseScreen extends ConsumerWidget {
  const TermsOfUseScreen({super.key});

  // Conteúdo de fallback exibido apenas se o banco estiver inacessível.
  static const _fallbackContent = '''
# Termos de Uso

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

*Estes Termos são efetivos a partir de 29 de março de 2026.*
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
    final docAsync = ref.watch(_termsOfUseProvider);

    return Scaffold(
      backgroundColor: theme.backgroundPrimary,
      appBar: AppBar(
        backgroundColor: theme.appBarBackground,
        foregroundColor: theme.appBarForeground,
        elevation: 0,
        centerTitle: true,
        surfaceTintColor: Colors.transparent,
        title: Text(
          s.termsOfUse,
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
