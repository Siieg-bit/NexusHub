#!/usr/bin/env python3
"""
Pass 6: Handle interpolated strings by adding methods with parameters
to the l10n files and replacing in source.
"""

import os
import re

PROJECT = "/home/ubuntu/NexusHub/frontend/lib"

# Interpolated strings that need methods instead of getters
# Format: (abstract_method, pt_impl, en_impl, file_path, old_string_pattern, new_call)
INTERPOLATED = [
    # $streak Dias na Sequência
    {
        'abstract': '  String streakDaysLabel(int streak);',
        'pt': "  @override\n  String streakDaysLabel(int streak) => '\$streak Dias na Sequência';",
        'en': "  @override\n  String streakDaysLabel(int streak) => '\$streak Day Streak';",
        'files': {
            'community_profile_screen.dart': ("'\\$streak Dias na Sequência'", 's.streakDaysLabel(streak)'),
        }
    },
    # ${diff.inDays ~/ 30}m atrás, ${diff.inDays}d atrás, etc.
    {
        'abstract': '  String timeAgoMonths(int months);',
        'pt': "  @override\n  String timeAgoMonths(int months) => '\${months}m atrás';",
        'en': "  @override\n  String timeAgoMonths(int months) => '\${months}m ago';",
        'files': {}  # These are in helpers.dart, complex interpolation
    },
    {
        'abstract': '  String timeAgoDays(int days);',
        'pt': "  @override\n  String timeAgoDays(int days) => '\${days}d atrás';",
        'en': "  @override\n  String timeAgoDays(int days) => '\${days}d ago';",
        'files': {}
    },
    {
        'abstract': '  String timeAgoHours(int hours);',
        'pt': "  @override\n  String timeAgoHours(int hours) => '\${hours}h atrás';",
        'en': "  @override\n  String timeAgoHours(int hours) => '\${hours}h ago';",
        'files': {}
    },
    {
        'abstract': '  String timeAgoMinutes(int minutes);',
        'pt': "  @override\n  String timeAgoMinutes(int minutes) => '\${minutes}min atrás';",
        'en': "  @override\n  String timeAgoMinutes(int minutes) => '\${minutes}min ago';",
        'files': {}
    },
    # ${post.viewsCount} visualizações
    {
        'abstract': '  String viewsCountLabel(int count);',
        'pt': "  @override\n  String viewsCountLabel(int count) => '\$count visualizações';",
        'en': "  @override\n  String viewsCountLabel(int count) => '\$count views';",
        'files': {}
    },
    # Opção ${i + 1}
    {
        'abstract': '  String optionNumber(int number);',
        'pt': "  @override\n  String optionNumber(int number) => 'Opção \$number';",
        'en': "  @override\n  String optionNumber(int number) => 'Option \$number';",
        'files': {}
    },
    # Ver ${count} comentários
    {
        'abstract': '  String viewCommentsCount(int count);',
        'pt': "  @override\n  String viewCommentsCount(int count) => 'Ver \$count comentários';",
        'en': "  @override\n  String viewCommentsCount(int count) => 'View \$count comments';",
        'files': {}
    },
    # Responda nos comentários abaixo • ${count} respostas
    {
        'abstract': '  String replyInComments(int count);',
        'pt': "  @override\n  String replyInComments(int count) => 'Responda nos comentários abaixo • \$count respostas';",
        'en': "  @override\n  String replyInComments(int count) => 'Reply in the comments below • \$count replies';",
        'files': {}
    },
    # Dia $_consecutiveDays de sequência!
    {
        'abstract': '  String dayOfStreak(int days);',
        'pt': "  @override\n  String dayOfStreak(int days) => 'Dia \$days de sequência!';",
        'en': "  @override\n  String dayOfStreak(int days) => 'Day \$days of streak!';",
        'files': {}
    },
    # Você ganhou X moedas extras!
    {
        'abstract': '  String wonExtraCoins(int coins);',
        'pt': "  @override\n  String wonExtraCoins(int coins) => 'Você ganhou \$coins moedas extras!';",
        'en': "  @override\n  String wonExtraCoins(int coins) => 'You won \$coins extra coins!';",
        'files': {}
    },
    # Nível X
    {
        'abstract': '  String levelLabel(int level);',
        'pt': "  @override\n  String levelLabel(int level) => 'Nível \$level';",
        'en': "  @override\n  String levelLabel(int level) => 'Level \$level';",
        'files': {}
    },
    # Ganhe 5 moedas grátis ($remaining restantes)
    {
        'abstract': '  String freeCoinsRemaining(int remaining);',
        'pt': "  @override\n  String freeCoinsRemaining(int remaining) => 'Ganhe 5 moedas grátis (\$remaining restantes)';",
        'en': "  @override\n  String freeCoinsRemaining(int remaining) => 'Earn 5 free coins (\$remaining remaining)';",
        'files': {}
    },
    # Check-in\nDiário
    {
        'abstract': '  String get checkInDaily;',
        'pt': "  @override\n  String get checkInDaily => 'Check-in\\nDiário';",
        'en': "  @override\n  String get checkInDaily => 'Daily\\nCheck-in';",
        'files': {}
    },
    # Quiz\nDiário
    {
        'abstract': '  String get quizDaily;',
        'pt': "  @override\n  String get quizDaily => 'Quiz\\nDiário';",
        'en': "  @override\n  String get quizDaily => 'Daily\\nQuiz';",
        'files': {}
    },
    # Chat\nPúblico
    {
        'abstract': '  String get chatPublicNewline;',
        'pt': "  @override\n  String get chatPublicNewline => 'Chat\\nPúblico';",
        'en': "  @override\n  String get chatPublicNewline => 'Public\\nChat';",
        'files': {}
    },
]

# Simple remaining strings for edit_guidelines defaults
GUIDELINE_STRINGS = {
    '1. Seja respeitoso com todos os membros\\n2. Não faça spam ou flood\\n3. Mantenha o conteúdo relevante à comunidade\\n4. Não compartilhe informações pessoais': 
        ('1. Be respectful to all members\\n2. No spam or flooding\\n3. Keep content relevant to the community\\n4. Do not share personal information', 'defaultGuidelines'),
    '• Posts relacionados ao tema da comunidade\\n• Fan arts e criações originais\\n• Discussões construtivas\\n• Memes relacionados ao tema':
        ('• Posts related to the community topic\\n• Fan arts and original creations\\n• Constructive discussions\\n• Topic-related memes', 'defaultAllowedContent'),
    '• NSFW / Conteúdo explícito\\n• Bullying ou assédio\\n• Roubo de arte (art theft)\\n• Propaganda não autorizada\\n• Conteúdo discriminatório':
        ('• NSFW / Explicit content\\n• Bullying or harassment\\n• Art theft\\n• Unauthorized advertising\\n• Discriminatory content', 'defaultProhibitedContent'),
    '• 1º Strike: Aviso formal\\n• 2º Strike: Silenciamento temporário (24h)\\n• 3º Strike: Ban permanente da comunidade':
        ('• 1st Strike: Formal warning\\n• 2nd Strike: Temporary mute (24h)\\n• 3rd Strike: Permanent community ban', 'defaultStrikePolicy'),
    '• Leader: Gerencia a comunidade e modera conteúdo\\n• Curator: Auxilia na moderação e curadoria de wikis\\n• Member: Participa ativamente da comunidade':
        ('• Leader: Manages the community and moderates content\\n• Curator: Assists in moderation and wiki curation\\n• Member: Actively participates in the community', 'defaultRoles'),
    'Escreva as guidelines da sua comunidade aqui...\\n\\nUse ## para títulos de seção\\nUse • ou - para listas\\nUse ** para negrito':
        ('Write your community guidelines here...\\n\\nUse ## for section titles\\nUse • or - for lists\\nUse ** for bold', 'guidelinesEditorHint'),
}


def main():
    # 1. Add method declarations to l10n files
    abstract_additions = []
    pt_additions = []
    en_additions = []
    
    # Load existing to check for duplicates
    with open(f"{PROJECT}/core/l10n/app_strings.dart", 'r') as f:
        existing_content = f.read()
    
    for item in INTERPOLATED:
        # Check if already exists
        method_name = re.search(r'String (?:get )?(\w+)', item['abstract']).group(1)
        if f'String {method_name}' in existing_content or f'get {method_name}' in existing_content:
            continue
        abstract_additions.append(item['abstract'])
        pt_additions.append(item['pt'])
        en_additions.append(item['en'])
    
    # Add guideline strings
    for pt_str, (en_str, key) in sorted(GUIDELINE_STRINGS.items(), key=lambda x: x[1][1]):
        if f'get {key}' in existing_content:
            continue
        abstract_additions.append(f"  String get {key};")
        pt_additions.append(f"  @override\n  String get {key} => '{pt_str}';")
        en_additions.append(f"  @override\n  String get {key} => '{en_str}';")
    
    for filepath, additions, comment in [
        (f"{PROJECT}/core/l10n/app_strings.dart", abstract_additions, "// PASS 6 — INTERPOLATED METHODS"),
        (f"{PROJECT}/core/l10n/app_strings_pt.dart", pt_additions, "// PASS 6 — INTERPOLATED METHODS"),
        (f"{PROJECT}/core/l10n/app_strings_en.dart", en_additions, "// PASS 6 — INTERPOLATED METHODS"),
    ]:
        if not additions:
            continue
        with open(filepath, 'r') as f:
            content = f.read()
        insert_text = f"\n  {comment}\n" + '\n'.join(additions) + '\n'
        content = content.rstrip().rstrip('}') + insert_text + '}\n'
        with open(filepath, 'w') as f:
            f.write(content)
    
    print(f"Added {len(abstract_additions)} new methods/keys to l10n files")
    
    # 2. Now do targeted replacements for interpolated strings in specific files
    replacements_done = 0
    
    # Handle specific file replacements
    # community_profile_screen.dart: $streak Dias na Sequência
    _replace_in_file(
        'community_profile_screen.dart',
        "'$streak Dias na Sequência'",  # The literal string in the file
        "s.streakDaysLabel(streak)",
    )
    
    # post_detail_screen.dart: viewsCount and commentsCount
    _replace_interpolated('post_detail_screen.dart', 
        "'${post.viewsCount} visualizações'",
        "s.viewsCountLabel(post.viewsCount)")
    
    _replace_interpolated('post_detail_screen.dart',
        "'Responda nos comentários abaixo • ${post.commentsCount} respostas'",
        "s.replyInComments(post.commentsCount)")
    
    # post_card.dart: Ver X comentários
    _replace_interpolated('post_card.dart',
        "'Ver ${_post.commentsCount} comentários'",
        "s.viewCommentsCount(_post.commentsCount)")
    
    # Opção ${i + 1} in multiple files
    for fname in ['create_poll_screen.dart', 'create_quiz_screen.dart', 'poll_quiz_widget.dart', 'post_card.dart']:
        _replace_interpolated(fname, "'Opção ${i + 1}'", "s.optionNumber(i + 1)")
        _replace_interpolated(fname, "'Opção ${oi + 1}'", "s.optionNumber(oi + 1)")
    
    # check_in_screen.dart
    _replace_interpolated('check_in_screen.dart',
        "'Dia $_consecutiveDays de sequência!'",
        "s.dayOfStreak(_consecutiveDays)")
    
    _replace_interpolated('check_in_screen.dart',
        "'Você ganhou $_luckyDrawPrize moedas extras!'",
        "s.wonExtraCoins(_luckyDrawPrize)")
    
    # search_screen.dart, moderation_actions_screen.dart: Nível X
    _replace_interpolated('search_screen.dart',
        "'Nível ${u['level'] ?? 1}'",
        "s.levelLabel(u['level'] as int? ?? 1)")
    
    _replace_interpolated('moderation_actions_screen.dart',
        "'Nível ${_targetUser?['level'] ?? 1}'",
        "s.levelLabel(_targetUser?['level'] as int? ?? 1)")
    
    # coin_shop_screen.dart
    _replace_interpolated('coin_shop_screen.dart',
        "'Ganhe 5 moedas grátis ($remaining restantes)'",
        "s.freeCoinsRemaining(remaining)")
    
    # global_feed_screen.dart: Check-in\nDiário, Quiz\nDiário
    _replace_interpolated('global_feed_screen.dart',
        "'Check-in\\nDiário'",
        "s.checkInDaily")
    
    _replace_interpolated('global_feed_screen.dart',
        "'Quiz\\nDiário'",
        "s.quizDaily")
    
    # community_chat_tab.dart or similar: Chat\nPúblico
    _replace_interpolated('community_chat_tab.dart',
        "'Chat\\nPúblico'",
        "s.chatPublicNewline")
    
    # edit_guidelines_screen.dart: guideline defaults
    for pt_str, (en_str, key) in GUIDELINE_STRINGS.items():
        _replace_interpolated('edit_guidelines_screen.dart', f"'{pt_str}'", f"s.{key}")
    
    print(f"\nDone with pass 6 interpolated replacements")


def _replace_in_file(filename, old, new):
    """Replace a string in a specific file by searching for it."""
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
                    print(f"  ✓ {filename}: replaced interpolated string")
                    return True
    return False


def _replace_interpolated(filename, old, new):
    """Replace interpolated string in file."""
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
                    print(f"  ✓ {filename}: replaced '{old[:40]}...'")
                    return True
    return False


if __name__ == '__main__':
    main()
