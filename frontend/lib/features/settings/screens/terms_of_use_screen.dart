import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../../../config/app_theme.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/l10n/locale_provider.dart';
import '../../../../config/nexus_theme_extension.dart';
import '../../../../config/nexus_theme_extension.dart';

/// Tela de Termos de Uso do NexusHub.
class TermsOfUseScreen extends ConsumerWidget {
  const TermsOfUseScreen({super.key});

  static const _content = '''
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
      final s = ref.watch(stringsProvider);
    final r = context.r;
    return Scaffold(
      backgroundColor: context.nexusTheme.backgroundPrimary,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: context.nexusTheme.textPrimary),
        title: Text(
          s.termsOfUse,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: context.nexusTheme.textPrimary,
          ),
        ),
      ),
      body: Markdown(
        data: _content,
        padding: EdgeInsets.all(r.s(16)),
        styleSheet: MarkdownStyleSheet(
          h1: TextStyle(
            color: context.nexusTheme.textPrimary,
            fontSize: r.fs(22),
            fontWeight: FontWeight.w800,
          ),
          h2: TextStyle(
            color: context.nexusTheme.textPrimary,
            fontSize: r.fs(17),
            fontWeight: FontWeight.w700,
          ),
          h3: TextStyle(
            color: context.nexusTheme.textPrimary,
            fontSize: r.fs(15),
            fontWeight: FontWeight.w600,
          ),
          p: TextStyle(
            color: context.nexusTheme.textSecondary,
            fontSize: r.fs(14),
            height: 1.6,
          ),
          strong: TextStyle(
            color: context.nexusTheme.textPrimary,
            fontWeight: FontWeight.w700,
          ),
          listBullet: TextStyle(
            color: context.nexusTheme.accentPrimary,
            fontSize: r.fs(14),
          ),
          horizontalRuleDecoration: BoxDecoration(
            border: Border(
              top: BorderSide(
                color: Colors.white.withValues(alpha: 0.1),
                width: 1,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
