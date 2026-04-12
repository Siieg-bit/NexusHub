import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../../../config/app_theme.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/l10n/locale_provider.dart';
import '../../../config/nexus_theme_extension.dart';

/// Tela de Política de Privacidade do NexusHub.
class PrivacyPolicyScreen extends ConsumerWidget {
  const PrivacyPolicyScreen({super.key});

  static const _content = '''
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
          s.privacyPolicyTitle,
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
