#!/usr/bin/env python3
"""
Fix reserved word keys, rename duplicates, then generate final l10n files
and apply them to the actual Dart source files.
"""

import json
import re

# Load the mapping
with open('/home/ubuntu/NexusHub/i18n_mapping.json', 'r') as f:
    data = json.load(f)

new_keys = data['new_keys']
keys_map = data['keys_map']

# Fix reserved words and problematic names
RENAMES = {
    'switch': 'switchCamera',
    'continue': 'continueAction',
    'delete2': 'deleteAction',
    'open2': 'openAction',
    'today2': 'todayLabel',
    'email2': 'emailHint',
    'following2': 'followingNow',
    'nickname2': 'nicknameHint',
    'stickers2': 'stickersLabel',
    'myCommunities2': 'myCommunitiesTitle',
    'createCommunity2': 'createCommunityTitle',
    'privacyPolicy2': 'privacyPolicyTitle',
    'logIn': 'logInAction',
}

# Apply renames to new_keys
for old_key, new_key in RENAMES.items():
    if old_key in new_keys:
        new_keys[new_key] = new_keys.pop(old_key)

# Apply renames to keys_map
for pt_str, key in list(keys_map.items()):
    if key in RENAMES:
        keys_map[pt_str] = RENAMES[key]

# Save updated mapping
data['new_keys'] = new_keys
data['keys_map'] = keys_map
with open('/home/ubuntu/NexusHub/i18n_mapping.json', 'w') as f:
    json.dump(data, f, ensure_ascii=False, indent=2)

# ============================================================================
# Now generate the actual Dart files
# ============================================================================

PROJECT = "/home/ubuntu/NexusHub/frontend/lib/core/l10n"

# Read existing files
with open(f"{PROJECT}/app_strings.dart", 'r') as f:
    abstract_content = f.read()

with open(f"{PROJECT}/app_strings_pt.dart", 'r') as f:
    pt_content = f.read()

with open(f"{PROJECT}/app_strings_en.dart", 'r') as f:
    en_content = f.read()

# Categorize keys
def categorize(key, pt_text):
    pt_lower = pt_text.lower()
    if any(w in pt_lower for w in ['login', 'senha', 'email', 'cadastr', 'conta', 'auth', 'sessão expirada']):
        return 'AUTH'
    if any(w in pt_lower for w in ['comunidade', 'membro', 'líder', 'curador', 'moderador', 'regra', 'link geral', 'módulo', 'acesso', 'layout', 'estatística']):
        return 'COMUNIDADES'
    if any(w in pt_lower for w in ['post', 'blog', 'enquete', 'quiz', 'pergunta', 'rascunho', 'publicar', 'bloco', 'parágrafo', 'cabeçalho', 'citação', 'código', 'divisor', 'lista', 'vot', 'opção', 'crosspost', 'poll']):
        return 'POSTS / FEED'
    if any(w in pt_lower for w in ['chat', 'mensag', 'grupo', 'convite', 'sticker', 'figurinha', 'chamada', 'fixar mensag', 'host', 'speaker', 'mic', 'mudo', 'câmera', 'trocar', 'encerrar']):
        return 'CHAT'
    if any(w in pt_lower for w in ['perfil', 'seguir', 'seguindo', 'mural', 'wiki entr', 'avatar', 'banner', 'bio local', 'apelido']):
        return 'PERFIL'
    if any(w in pt_lower for w in ['wiki', 'entrada']):
        return 'WIKI'
    if any(w in pt_lower for w in ['moderação', 'denúncia', 'banir', 'expulsar', 'silenciar', 'strike', 'report', 'spam', 'assédio', 'ódio', 'violência']):
        return 'MODERAÇÃO'
    if any(w in pt_lower for w in ['configuração', 'dispositivo', 'privacidade', 'bloqueado', 'permissão', 'notificação', 'cache', 'exportar', 'tema', 'idioma', 'aparência', 'segurança']):
        return 'CONFIGURAÇÕES'
    if any(w in pt_lower for w in ['moeda', 'carteira', 'saldo', 'transação', 'recompensa', 'check-in', 'conquista', 'inventário', 'ranking', 'classificação', 'equipar', 'nível']):
        return 'GAMIFICAÇÃO'
    if any(w in pt_lower for w in ['loja', 'comprar', 'pacote', 'moldura', 'título', 'fundo', 'bolha', 'premium', 'restaurar']):
        return 'LOJA'
    if any(w in pt_lower for w in ['story', 'stories']):
        return 'STORIES'
    if any(w in pt_lower for w in ['live', 'ao vivo', 'exibição', 'espectador']):
        return 'LIVE'
    if any(w in pt_lower for w in ['buscar', 'pesquisar', 'filtrar', 'ordenar']):
        return 'BUSCA'
    if any(w in pt_lower for w in ['janeiro', 'fevereiro', 'março', 'abril', 'maio', 'junho', 'julho', 'agosto', 'setembro', 'outubro', 'novembro', 'dezembro', 'dia', 'semana', 'mês', 'ano', 'hoje', 'ontem', 'amanhã', 'agora']):
        return 'TEMPO / MESES'
    if any(w in pt_lower for w in ['erro', 'falha', 'indisponível', 'negado', 'não encontrado', 'não permitid']):
        return 'ERROS'
    return 'GERAL'

categories = {}
for key, vals in sorted(new_keys.items()):
    cat = categorize(key, vals['pt'])
    if cat not in categories:
        categories[cat] = []
    categories[cat].append((key, vals['pt'], vals['en']))

# Build additions
abstract_additions = []
pt_additions = []
en_additions = []

cat_order = ['AUTH', 'COMUNIDADES', 'POSTS / FEED', 'CHAT', 'PERFIL', 'WIKI',
             'MODERAÇÃO', 'CONFIGURAÇÕES', 'GAMIFICAÇÃO', 'LOJA', 'STORIES',
             'LIVE', 'BUSCA', 'TEMPO / MESES', 'ERROS', 'GERAL']

for cat_name in cat_order:
    items = categories.get(cat_name, [])
    if not items:
        continue
    abstract_additions.append(f"\n  // {cat_name} (NOVOS)")
    pt_additions.append(f"\n  // ══════════════════════════════════════════════════════════════════════════")
    pt_additions.append(f"  // {cat_name} (NOVOS)")
    pt_additions.append(f"  // ══════════════════════════════════════════════════════════════════════════")
    en_additions.append(f"\n  // {cat_name} (NEW)")
    
    for key, pt_val, en_val in sorted(items, key=lambda x: x[0]):
        abstract_additions.append(f"  String get {key};")
        pt_escaped = pt_val.replace("'", "\\'")
        en_escaped = en_val.replace("'", "\\'")
        pt_additions.append(f"  @override\n  String get {key} => '{pt_escaped}';")
        en_additions.append(f"  @override\n  String get {key} => '{en_escaped}';")

# Insert into files (before closing brace)
abstract_insert = '\n'.join(abstract_additions)
pt_insert = '\n'.join(pt_additions)
en_insert = '\n'.join(en_additions)

# Replace the closing brace with additions + closing brace
abstract_new = abstract_content.rstrip().rstrip('}') + '\n' + abstract_insert + '\n}\n'
pt_new = pt_content.rstrip().rstrip('}') + '\n' + pt_insert + '\n}\n'
en_new = en_content.rstrip().rstrip('}') + '\n' + en_insert + '\n}\n'

# Write files
with open(f"{PROJECT}/app_strings.dart", 'w') as f:
    f.write(abstract_new)

with open(f"{PROJECT}/app_strings_pt.dart", 'w') as f:
    f.write(pt_new)

with open(f"{PROJECT}/app_strings_en.dart", 'w') as f:
    f.write(en_new)

print(f"Updated app_strings.dart with {len(new_keys)} new abstract getters")
print(f"Updated app_strings_pt.dart with {len(new_keys)} new PT translations")
print(f"Updated app_strings_en.dart with {len(new_keys)} new EN translations")
