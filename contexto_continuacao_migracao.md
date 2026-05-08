# Contexto de continuação — Migração APK → Servidor

A conversa compartilhada indica que foi feita uma varredura profunda no NexusHub para identificar dados e configurações ainda hardcoded no APK. O relatório enviado pelo usuário confirma que já foram migrados para servidor: temas visuais, textos legais, categorias de interesse, limites e paginação, rate limits, regras de gamificação, links/webhooks, anúncios/IAP, conquistas e loja.

As oportunidades restantes foram classificadas assim:

| Prioridade | Item | Caminho recomendado |
|---|---|---|
| Alta | Textos de recompensa da tela Free Coins | Remote Config com chaves `ui.rewards.*` |
| Alta | Títulos de nível | Tabela `level_titles` ou JSON no Remote Config |
| Alta | Cores de nível | JSON `ui.level_colors` no Remote Config |
| Média | Slides de onboarding | Tabela `onboarding_slides` |
| Média | System announcements | Usar tabela `system_announcements` existente |
| Média | Domínios de streaming | Remote Config `features.allowed_stream_domains` |
| Baixa/alto impacto | Strings de localização | OTA Translations via Supabase Storage ou serviço externo |
| Baixa | Cache TTLs | Remote Config `cache.ttl.*` |

O relatório recomenda como próxima etapa máxima implementar OTA Translations. Contudo, a implementação deve ser feita com cuidado porque `app_strings.dart` define uma interface grande com getters tipados e o app usa `stringsProvider`. Uma estratégia incremental segura é manter os getters e fallbacks locais, adicionar um serviço de overlays remotos por idioma, e fazer as classes de idioma consultarem chaves remotas quando disponíveis. Isso permite reduzir necessidade de recompilação para correção de textos, sem quebrar o app offline.
