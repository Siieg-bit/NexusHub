# Checklist Final de Pendências — NexusHub vs Amino Apps

Pendências extraídas dos 3 documentos de auditoria, cruzadas com o código atual.

## Prioridade ALTA (Core Features)

- [x] 1. **Tela de Editar Perfil da Comunidade** — Não existe rota nem tela. O botão "Editar" no community_profile_screen navega para `/community/:id/profile/edit` que não existe no router. Precisa de tela com: nickname local, bio local, avatar local, banner local.
- [x] 2. **Poll/Quiz UI no PostDetailScreen** — O PostCard já tem `_buildPoll()` e `_buildQuiz()` com votação funcional, mas o PostDetailScreen (tela de detalhe) NÃO renderiza polls nem quizzes. Precisa replicar a UI de votação/resposta no detalhe.
- [x] 3. **Animação de Level Up** — O check-in detecta `level_up == true` mas só mostra um SnackBar. No Amino, subir de nível gera um dialog fullscreen com confetti, novo título e animação.
- [x] 4. **Provider Global de Cosméticos** — `AvatarWithFrame` só é usado em 2 locais (profile_screen e community_profile_screen). Falta usar em: lista de membros, comentários, chat list, leaderboard, post_card author. Precisa de um Provider global que cache os cosméticos equipados de cada usuário.
- [x] 5. **Crosspost entre Comunidades** — CrosspostPicker integrado no create_post_screen com seleção de comunidade destino, campo corrigido para `original_community_id`, post-espelho criado na comunidade destino, e renderização de crosspost/repost no PostCard com banner clicável.
- [x] 6. **Wiki: Revisão por Curadores + Pin no Perfil** — Tela WikiCuratorReviewScreen criada com aprovação/rejeição + notificação ao autor + log de moderação. CreateWikiScreen submete como 'pending'. WikiDetailScreen com botão de pin (via bookmarks.wiki_id). Seção Pinned Wikis no perfil com scroll horizontal. Rota /community/:id/wiki/review adicionada. Botão de revisão na WikiListScreen.

## Prioridade MÉDIA (Nice to Have)

- [x] 7. **Deep Links Reais** — DeepLinkService completo com custom scheme (nexushub://), web links (https://nexushub.app/), suporte para community/post/user/chat/invite/wiki. AndroidManifest.xml configurado com intent-filters e autoVerify. iOS Info.plist com CFBundleURLTypes e FlutterDeepLinkingEnabled. Runner.entitlements com Associated Domains para Universal Links.
- [x] 8. **Cache Offline-First** — CacheService completo com Hive. Boxes: posts, communities, messages, profiles, feed, notifications, wiki, metadata. Estratégia cache-first com timestamps de sincronização, expiração configurável, append de mensagens, cálculo de tamanho do cache, limpar cache. Integrado no main.dart.
- [ ] 9. **Internacionalização (i18n)** — Textos hardcoded em português. Nenhum uso de `flutter_localizations` ou `AppLocalizations`.

## Prioridade BAIXA (Polish)

- [ ] 10. **Temas Customizáveis** — `theme_provider.dart` existe mas só tem dark theme. Adicionar light theme funcional.
- [ ] 11. **Animações de Transição** — `flutter_animate` está no pubspec mas pouco usado. Melhorar transições entre telas.
