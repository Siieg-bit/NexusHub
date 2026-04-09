#!/usr/bin/env python3
"""
Pass 7: Final cleanup of the last remaining Portuguese strings.
These are complex interpolated strings that need targeted manual replacement.
"""

import os
import re

PROJECT = "/home/ubuntu/NexusHub/frontend/lib"

# New methods and getters needed
NEW_ABSTRACT = [
    '  String get yourUniqueIdDesc;',
    '  String confirmationEmailSent(String email);',
    '  String get mediaLabel;',
    '  String get moderationActions30d;',
    '  String joinedCommunityName(String name);',
    '  String checkInStreakMsg(int streak, int coins);',
    '  String get leadersTitle;',
    '  String levelAndRep(int level, int reputation);',
    '  String get communityNameRequired;',
    '  String timeAgoMonthsShort(int months);',
    '  String timeAgoDaysShort(int days);',
    '  String timeAgoHoursShort(int hours);',
    '  String timeAgoMinutesShort(int minutes);',
    '  String get justNow;',
    '  String receivedWarning(String reason);',
    '  String removedFromCommunity(String reason);',
    '  String get aminoIdInUse;',
    '  String get tryAgainGeneric;',
    '  String pausedUntil(String dateTime);',
    '  String entryApprovedMsg(String title);',
    '  String entryNeedsChanges(String title, String reason);',
    '  String get textOverflowHint;',
]

NEW_PT = [
    "  @override\n  String get yourUniqueIdDesc => 'Seu ID único é como outros membros vão te encontrar. ';",
    "  @override\n  String confirmationEmailSent(String email) => 'Enviamos um link de confirmação para \$email.\\n\\n';",
    "  @override\n  String get mediaLabel => 'mídia';",
    "  @override\n  String get moderationActions30d => 'Ações de Moderação (30d)';",
    "  @override\n  String joinedCommunityName(String name) => 'Você entrou em \"\$name\"!';",
    "  @override\n  String checkInStreakMsg(int streak, int coins) => 'Check-in feito! Sequência: \$streak dia\${streak > 1 ? \"s\" : \"\"} (+\$coins moedas)';",
    "  @override\n  String get leadersTitle => 'LÍDERES';",
    "  @override\n  String levelAndRep(int level, int reputation) => 'Nível \$level • \$reputation rep';",
    "  @override\n  String get communityNameRequired => 'O nome da comunidade é obrigatório.';",
    "  @override\n  String timeAgoMonthsShort(int months) => '\${months}m atrás';",
    "  @override\n  String timeAgoDaysShort(int days) => '\${days}d atrás';",
    "  @override\n  String timeAgoHoursShort(int hours) => '\${hours}h atrás';",
    "  @override\n  String timeAgoMinutesShort(int minutes) => '\${minutes}min atrás';",
    "  @override\n  String get justNow => 'agora';",
    "  @override\n  String receivedWarning(String reason) => 'Você recebeu um aviso: \$reason';",
    "  @override\n  String removedFromCommunity(String reason) => 'Você foi removido da comunidade: \$reason';",
    "  @override\n  String get aminoIdInUse => 'Esse Amino ID já está em uso.';",
    "  @override\n  String get tryAgainGeneric => 'Tente novamente.';",
    "  @override\n  String pausedUntil(String dateTime) => 'Pausado até \$dateTime';",
    "  @override\n  String entryApprovedMsg(String title) => 'Sua entrada \"\$title\" foi aprovada e está visível no catálogo.';",
    "  @override\n  String entryNeedsChanges(String title, String reason) => 'Sua entrada \"\$title\" precisa de alterações: \$reason';",
    "  @override\n  String get textOverflowHint => '║  TextOverflow.ellipsis no widget de texto responsável.   ║\\n';",
]

NEW_EN = [
    "  @override\n  String get yourUniqueIdDesc => 'Your unique ID is how other members will find you. ';",
    "  @override\n  String confirmationEmailSent(String email) => 'We sent a confirmation link to \$email.\\n\\n';",
    "  @override\n  String get mediaLabel => 'media';",
    "  @override\n  String get moderationActions30d => 'Moderation Actions (30d)';",
    "  @override\n  String joinedCommunityName(String name) => 'You joined \"\$name\"!';",
    "  @override\n  String checkInStreakMsg(int streak, int coins) => 'Check-in done! Streak: \$streak day\${streak > 1 ? \"s\" : \"\"} (+\$coins coins)';",
    "  @override\n  String get leadersTitle => 'LEADERS';",
    "  @override\n  String levelAndRep(int level, int reputation) => 'Level \$level • \$reputation rep';",
    "  @override\n  String get communityNameRequired => 'The community name is required.';",
    "  @override\n  String timeAgoMonthsShort(int months) => '\${months}mo ago';",
    "  @override\n  String timeAgoDaysShort(int days) => '\${days}d ago';",
    "  @override\n  String timeAgoHoursShort(int hours) => '\${hours}h ago';",
    "  @override\n  String timeAgoMinutesShort(int minutes) => '\${minutes}min ago';",
    "  @override\n  String get justNow => 'just now';",
    "  @override\n  String receivedWarning(String reason) => 'You received a warning: \$reason';",
    "  @override\n  String removedFromCommunity(String reason) => 'You were removed from the community: \$reason';",
    "  @override\n  String get aminoIdInUse => 'This Amino ID is already in use.';",
    "  @override\n  String get tryAgainGeneric => 'Try again.';",
    "  @override\n  String pausedUntil(String dateTime) => 'Paused until \$dateTime';",
    "  @override\n  String entryApprovedMsg(String title) => 'Your entry \"\$title\" was approved and is visible in the catalog.';",
    "  @override\n  String entryNeedsChanges(String title, String reason) => 'Your entry \"\$title\" needs changes: \$reason';",
    "  @override\n  String get textOverflowHint => '║  TextOverflow.ellipsis on the responsible text widget.   ║\\n';",
]


def add_to_l10n():
    for filepath, additions, comment in [
        (f"{PROJECT}/core/l10n/app_strings.dart", NEW_ABSTRACT, "// PASS 7 — FINAL INTERPOLATED"),
        (f"{PROJECT}/core/l10n/app_strings_pt.dart", NEW_PT, "// PASS 7 — FINAL INTERPOLATED"),
        (f"{PROJECT}/core/l10n/app_strings_en.dart", NEW_EN, "// PASS 7 — FINAL INTERPOLATED"),
    ]:
        with open(filepath, 'r') as f:
            content = f.read()
        insert_text = f"\n  {comment}\n" + '\n'.join(additions) + '\n'
        content = content.rstrip().rstrip('}') + insert_text + '}\n'
        with open(filepath, 'w') as f:
            f.write(content)
    print(f"Added {len(NEW_ABSTRACT)} new methods to l10n files")


def targeted_replacements():
    """Do targeted replacements in specific files."""
    
    # interest_wizard_screen.dart: yourUniqueIdDesc
    _replace('interest_wizard_screen.dart',
        "'Seu ID único é como outros membros vão te encontrar. '",
        "s.yourUniqueIdDesc")
    
    # onboarding_screen.dart: agreeTermsAndPrivacy
    _replace('onboarding_screen.dart',
        "'Ao continuar, você concorda com os Termos de Uso\\ne Política de Privacidade.'",
        "s.agreeTermsAndPrivacy")
    
    # signup_screen.dart: confirmationEmailSent
    _replace('signup_screen.dart',
        "'Enviamos um link de confirmação para $email.\\n\\n'",
        "s.confirmationEmailSent(email)")
    
    # forward_message_sheet.dart: mediaLabel
    _replace('forward_message_sheet.dart',
        "'mídia'",
        "s.mediaLabel")
    
    # acm_screen.dart: moderationActions30d
    _replace('acm_screen.dart',
        "'Ações de Moderação (30d)'",
        "s.moderationActions30d")
    
    # community_general_links_screen.dart: addUsefulLinks (already done, but check)
    _replace('community_general_links_screen.dart',
        "'Adicione links úteis para os membros\\nda sua comunidade.'",
        "s.addUsefulLinks")
    
    # community_info_screen.dart: joinedCommunityName
    _replace('community_info_screen.dart',
        """'Você entrou em "\${_community?.name ?? ''}"!'""",
        "s.joinedCommunityName(_community?.name ?? '')")
    
    # community_list_screen.dart & community_drawer.dart: checkInStreakMsg
    _replace('community_list_screen.dart',
        """'Check-in feito! Sequência: $streak dia\${streak > 1 ? 's' : ''} (+$coins moedas)'""",
        "s.checkInStreakMsg(streak, coins)")
    
    _replace('community_drawer.dart',
        """'Check-in feito! Sequência: $streak dia\${streak > 1 ? 's' : ''} (+$coins moedas)'""",
        "s.checkInStreakMsg(streak, coins)")
    
    # community_members_screen.dart: leadersTitle
    _replace('community_members_screen.dart',
        "'LÍDERES'",
        "s.leadersTitle")
    
    # community_search_screen.dart: levelAndRep
    _replace('community_search_screen.dart',
        "'Nível $level • $reputation rep'",
        "s.levelAndRep(level, reputation)")
    
    # create_community_screen.dart: communityNameRequired
    _replace('create_community_screen.dart',
        "'O nome da comunidade é obrigatório.'",
        "s.communityNameRequired")
    
    # shared_folder_screen.dart: time ago methods
    _replace('shared_folder_screen.dart',
        "'${diff.inDays ~/ 30}m atrás'",
        "s.timeAgoMonthsShort(diff.inDays ~/ 30)")
    _replace('shared_folder_screen.dart',
        "'${diff.inDays}d atrás'",
        "s.timeAgoDaysShort(diff.inDays)")
    _replace('shared_folder_screen.dart',
        "'${diff.inHours}h atrás'",
        "s.timeAgoHoursShort(diff.inHours)")
    _replace('shared_folder_screen.dart',
        "'${diff.inMinutes}min atrás'",
        "s.timeAgoMinutesShort(diff.inMinutes)")
    
    # community_create_menu.dart: chatPublicNewline
    _replace('community_create_menu.dart',
        "'Chat\\nPúblico'",
        "s.chatPublicNewline")
    
    # moderation_actions_screen.dart: receivedWarning, removedFromCommunity
    _replace('moderation_actions_screen.dart',
        "'Você recebeu um aviso: ${_reasonController.text.trim()}'",
        "s.receivedWarning(_reasonController.text.trim())")
    _replace('moderation_actions_screen.dart',
        "'Você foi removido da comunidade: ${_reasonController.text.trim()}'",
        "s.removedFromCommunity(_reasonController.text.trim())")
    
    # notifications_screen.dart: interactionsAppearHere
    _replace('notifications_screen.dart',
        "'Quando alguém interagir com você,\\naparecerá aqui'",
        "s.interactionsAppearHere")
    
    # edit_profile_screen.dart: aminoIdInUse + tryAgainGeneric
    # This one is complex: 'Erro ao salvar: ${e.toString().contains('duplicate') ? 'Esse Amino ID já está em uso.' : 'Tente novamente.'}'
    _replace('edit_profile_screen.dart',
        "'Esse Amino ID já está em uso.'",
        "s.aminoIdInUse")
    _replace('edit_profile_screen.dart',
        "'Tente novamente.'",
        "s.tryAgainGeneric")
    
    # blocked_users_screen.dart: blockedUsersCannotSeeProfile
    _replace('blocked_users_screen.dart',
        "'Usuários bloqueados não podem ver seu perfil\\n'",
        "s.blockedUsersCannotSeeProfile")
    
    # notification_settings_screen.dart: pausedUntil (complex)
    # This is very complex with inline date formatting, we'll replace the whole expression
    # For now, leave as is since it requires restructuring
    
    # wiki_curator_review_screen.dart: entryApprovedMsg, entryNeedsChanges
    _replace('wiki_curator_review_screen.dart',
        """'Sua entrada "\${entry['title']}" foi aprovada e está visível no catálogo.'""",
        "s.entryApprovedMsg(entry['title'] as String? ?? '')")
    _replace('wiki_curator_review_screen.dart',
        """'Sua entrada "\${entry['title']}" precisa de alterações: \${rejectReason ?? ""}'""",
        "s.entryNeedsChanges(entry['title'] as String? ?? '', rejectReason ?? '')")
    
    # error_boundary.dart: textOverflowHint
    _replace('error_boundary.dart',
        "'║  TextOverflow.ellipsis no widget de texto responsável.   ║\\n'",
        "s.textOverflowHint")


def _replace(filename, old, new):
    for root, dirs, files in os.walk(PROJECT):
        for f in files:
            if f == filename:
                filepath = os.path.join(root, f)
                with open(filepath, 'r') as fh:
                    content = fh.read()
                if old in content:
                    content = content.replace(old, new)
                    with open(filepath, 'w') as fh:
                        fh.write(content)
                    print(f"  ✓ {filename}")
                    return True
    return False


def main():
    add_to_l10n()
    targeted_replacements()
    print("\nPass 7 complete!")


if __name__ == '__main__':
    main()
