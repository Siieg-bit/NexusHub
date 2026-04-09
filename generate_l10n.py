#!/usr/bin/env python3
"""
Generate updated AppStrings, AppStringsPt, AppStringsEn files
from the i18n_mapping.json produced by i18n_tool.py.
"""

import json

with open('/home/ubuntu/NexusHub/i18n_mapping.json', 'r') as f:
    data = json.load(f)

new_keys = data['new_keys']

# ============================================================================
# Generate additions to app_strings.dart
# ============================================================================
abstract_additions = []
pt_additions = []
en_additions = []

# Group by category based on key patterns
categories = {
    'AUTH': [],
    'COMUNIDADES': [],
    'POSTS / FEED': [],
    'CHAT': [],
    'PERFIL': [],
    'WIKI': [],
    'MODERAÇÃO': [],
    'CONFIGURAÇÕES': [],
    'GAMIFICAÇÃO': [],
    'LOJA': [],
    'STORIES': [],
    'LIVE': [],
    'BUSCA': [],
    'TEMPO / MESES': [],
    'ERROS': [],
    'GERAL': [],
}

def categorize(key, pt_text):
    pt_lower = pt_text.lower()
    if any(w in pt_lower for w in ['login', 'senha', 'email', 'cadastr', 'conta', 'auth']):
        return 'AUTH'
    if any(w in pt_lower for w in ['comunidade', 'membro', 'líder', 'curador', 'moderador', 'regra', 'link geral', 'módulo', 'acesso', 'visual', 'layout', 'estatística']):
        return 'COMUNIDADES'
    if any(w in pt_lower for w in ['post', 'blog', 'enquete', 'quiz', 'pergunta', 'rascunho', 'publicar', 'bloco', 'parágrafo', 'cabeçalho', 'citação', 'código', 'divisor', 'lista', 'vot', 'opção', 'crosspost', 'poll']):
        return 'POSTS / FEED'
    if any(w in pt_lower for w in ['chat', 'mensag', 'grupo', 'convite', 'sticker', 'figurinha', 'chamada', 'moeda', 'fixar mensag', 'host', 'speaker', 'mic', 'mudo', 'câmera', 'trocar', 'encerrar']):
        return 'CHAT'
    if any(w in pt_lower for w in ['perfil', 'seguir', 'seguindo', 'mural', 'wiki entr', 'avatar', 'banner', 'bio', 'apelido', 'nickname']):
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

for key, vals in sorted(new_keys.items()):
    cat = categorize(key, vals['pt'])
    categories[cat].append((key, vals['pt'], vals['en']))

# Generate the three files
print("Generating app_strings.dart additions...")

abstract_lines = []
pt_lines = []
en_lines = []

for cat_name, items in categories.items():
    if not items:
        continue
    abstract_lines.append(f"\n  // {cat_name} (NOVOS)")
    pt_lines.append(f"\n  // {cat_name} (NOVOS)")
    en_lines.append(f"\n  // {cat_name} (NOVOS)")
    
    for key, pt_val, en_val in sorted(items, key=lambda x: x[0]):
        abstract_lines.append(f"  String get {key};")
        # Escape single quotes in values
        pt_escaped = pt_val.replace("'", "\\'")
        en_escaped = en_val.replace("'", "\\'")
        pt_lines.append(f"  @override\n  String get {key} => '{pt_escaped}';")
        en_lines.append(f"  @override\n  String get {key} => '{en_escaped}';")

# Write the additions to files
with open('/home/ubuntu/NexusHub/l10n_abstract_additions.txt', 'w') as f:
    f.write('\n'.join(abstract_lines))

with open('/home/ubuntu/NexusHub/l10n_pt_additions.txt', 'w') as f:
    f.write('\n'.join(pt_lines))

with open('/home/ubuntu/NexusHub/l10n_en_additions.txt', 'w') as f:
    f.write('\n'.join(en_lines))

print(f"Generated {len(new_keys)} new key additions for all 3 files")
print("Files saved: l10n_abstract_additions.txt, l10n_pt_additions.txt, l10n_en_additions.txt")
