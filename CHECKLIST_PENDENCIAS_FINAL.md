# Checklist Final de Pendências — NexusHub vs Amino Apps

Pendências extraídas dos 3 documentos de auditoria, cruzadas com o código atual.

## Prioridade ALTA (Core Features)

- [x] 1. **Tela de Editar Perfil da Comunidade** — Não existe rota nem tela. O botão "Editar" no community_profile_screen navega para `/community/:id/profile/edit` que não existe no router. Precisa de tela com: nickname local, bio local, avatar local, banner local.
- [x] 2. **Poll/Quiz UI no PostDetailScreen** — O PostCard já tem `_buildPoll()` e `_buildQuiz()` com votação funcional, mas o PostDetailScreen (tela de detalhe) NÃO renderiza polls nem quizzes. Precisa replicar a UI de votação/resposta no detalhe.
- [ ] 3. **Animação de Level Up** — O check-in detecta `level_up == true` mas só mostra um SnackBar. No Amino, subir de nível gera um dialog fullscreen com confetti, novo título e animação.
- [ ] 4. **Provider Global de Cosméticos** — `AvatarWithFrame` só é usado em 2 locais (profile_screen e community_profile_screen). Falta usar em: lista de membros, comentários, chat list, leaderboard, post_card author. Precisa de um Provider global que cache os cosméticos equipados de cada usuário.
- [ ] 5. **Crosspost entre Comunidades** — O modelo suporta `type: crosspost` e o create_post_screen tem a opção, mas não há UI para selecionar a comunidade destino.
- [ ] 6. **Wiki: Revisão por Curadores + Pin no Perfil** — Não existe fluxo de submissão à Wiki Global com revisão por curadores, nem funcionalidade de "Pinar" wikis aprovadas no perfil do usuário.

## Prioridade MÉDIA (Nice to Have)

- [ ] 7. **Deep Links Reais** — `deep_link_service.dart` existe e `app_links` está no pubspec, mas falta configuração real no AndroidManifest.xml e Info.plist.
- [ ] 8. **Cache Offline-First** — `hive_flutter` está no pubspec mas nunca é usado. Implementar cache local para posts e mensagens.
- [ ] 9. **Internacionalização (i18n)** — Textos hardcoded em português. Nenhum uso de `flutter_localizations` ou `AppLocalizations`.

## Prioridade BAIXA (Polish)

- [ ] 10. **Temas Customizáveis** — `theme_provider.dart` existe mas só tem dark theme. Adicionar light theme funcional.
- [ ] 11. **Animações de Transição** — `flutter_animate` está no pubspec mas pouco usado. Melhorar transições entre telas.
