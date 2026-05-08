# Checklist de Migração APK → Servidor — NexusHub

Autor: **Manus AI**  
Data de início: **2026-05-07**  
Escopo imediato: **OTA Translations com fallback local, sem quebrar uso offline e sem deixar código parcialmente migrado.**

## Princípios obrigatórios

Esta migração deve reduzir a necessidade de publicar novos APKs para ajustes operacionais, conteúdo textual, configurações e experimentos. A implementação deve preservar a experiência offline, manter fallback local, evitar acoplamento frágil e permitir rollback seguro. Nenhuma etapa iniciada deve permanecer incompleta; caso uma alternativa apresente risco técnico relevante, ela deve ser corrigida ou revertida antes de avançar.

| Princípio | Aplicação prática | Status |
|---|---|---|
| **Fallback local sempre disponível** | O app deve continuar funcional sem rede ou sem Supabase. | Em andamento |
| **Mudança incremental e reversível** | Evitar alterações massivas em arquivos estáveis quando houver arquitetura mais isolada. | Em revisão |
| **Sem segredo no APK** | Apenas chaves públicas/anon e dados públicos podem estar no cliente. | Pendente validar |
| **Validação antes de commit** | Todo código Dart/SQL precisa passar por checagens estáticas possíveis no ambiente. | Pendente |
| **Ordem de produção explícita** | Migration, seed, app, feature flag, teste e rollout devem estar documentados. | Pendente |

## Auditoria do estado atual

Foi iniciada uma primeira abordagem de OTA Translations. Ela criou um serviço de cache/lookup remoto, uma migration `241_app_translations.sql` e alterou automaticamente todos os arquivos `app_strings_*.dart` para envolver getters simples com `OtaTranslationService.translate(...)`. A auditoria mostrou que essa abordagem funciona conceitualmente, mas produz um diff muito grande em arquivos de idioma estáveis, dificultando revisão e aumentando risco de regressão. Também foram detectados artefatos Unicode em português durante a geração, já corrigidos, o que reforça a necessidade de uma arquitetura menos invasiva.

| Item auditado | Resultado | Decisão |
|---|---|---|
| Serviço `ota_translation_service.dart` | Criado, mas ainda precisa revisão final de API/cache. | Manter e revisar. |
| Migration `241_app_translations.sql` | Criada com tabela, policies, RPC e seed inicial. | Manter, mas validar SQL e tamanho. |
| Alterações em `app_strings_*.dart` | Aproximadamente 30 mil getters alterados automaticamente. | Refatorar para reduzir risco. |
| `main.dart` | Inicializa OTA após Remote Config. | Manter se serviço ficar estável. |
| Scripts de análise/geração | Úteis para auditoria e geração controlada. | Manter apenas os que forem necessários e documentados. |

## Plano de arquitetura aprovado para seguir

A alternativa mais segura para produção é **não modificar diretamente todos os arquivos de idioma existentes**. Em vez disso, a migração deve gerar uma camada isolada `OtaAppStrings`, que implementa `AppStrings`, recebe uma instância local como fallback e aplica overlay remoto apenas nos getters simples. Métodos parametrizados e pluralizações continuam delegando diretamente para a implementação local até uma etapa posterior específica.

| Camada | Responsabilidade | Critério de pronto |
|---|---|---|
| Banco `app_translations` | Armazenar traduções por `locale` e `key`, com RLS e leitura pública controlada. | Migration revisada e idempotente. |
| RPC `get_app_translations(locale)` | Retornar JSON `{key: value}` somente de traduções ativas. | Validada por inspeção SQL. |
| Serviço Flutter | Buscar traduções, salvar cache local e oferecer fallback local. | Sem exceções fatais quando offline. |
| Wrapper `OtaAppStrings` | Aplicar overlay sem tocar nos arquivos `app_strings_*.dart`. | Gerado e integrado ao provider. |
| Provider/localização | Retornar `OtaAppStrings(base, locale)` quando apropriado. | Mantém API atual do app. |
| Documentação de produção | Definir ordem de aplicação, rollback e testes. | Documento atualizado antes do commit. |

## Checklist operacional

| Etapa | Descrição | Status |
|---|---|---|
| 1 | Consolidar contexto do relatório e conversa anterior. | Concluído |
| 2 | Auditar alterações já iniciadas e identificar riscos. | Concluído |
| 3 | Criar checklist versionada e mantê-la atualizada. | Concluído |
| 4 | Reverter/refatorar abordagem massiva nos arquivos `app_strings_*.dart`. | Concluído |
| 5 | Gerar wrapper OTA isolado com fallback local. | Concluído |
| 6 | Revisar serviço `OtaTranslationService` para cache, inicialização, timeout e erro offline. | Concluído |
| 7 | Revisar migration `241_app_translations.sql` para RLS, RPC e seed. | Concluído |
| 8 | Integrar wrapper no provider sem quebrar troca de idioma. | Concluído |
| 9 | Executar validações disponíveis no ambiente. | Concluído |
| 10 | Atualizar plano de produção e rollback. | Concluído |
| 11 | Criar commit e push somente após validação. | Em andamento |

## Ordem correta para produção

| Ordem | Ação | Observação |
|---:|---|---|
| 1 | Aplicar migration no Supabase de staging. | Não iniciar rollout no app antes de validar a tabela/RPC. |
| 2 | Popular seed inicial das traduções atuais. | Garante paridade com o APK existente. |
| 3 | Publicar build interno com OTA ativo e fallback local. | Testar offline, troca de idioma e cold start. |
| 4 | Ajustar uma string em staging pelo banco/admin. | Confirmar atualização sem novo APK. |
| 5 | Validar métricas/logs de falha silenciosa. | Erros de rede não podem afetar UI. |
| 6 | Promover migration para produção. | Somente após staging validado. |
| 7 | Fazer rollout gradual do app. | Monitorar sessões, crash rate e feedback. |

## Observações abertas

Validação executada: `python3.11 scripts/validate_ota_translations.py` retornou OK, com 3053 getters cobertos, 85 métodos delegados e 29950 linhas de seed. O ambiente atual não possui `dart` nem `flutter` no PATH, então a análise estática oficial do Flutter deve ser executada no CI ou em uma máquina de desenvolvimento antes de promover para produção.

Até o momento, a maior melhoria técnica identificada é substituir o diff massivo por um wrapper gerado e isolado. Essa decisão reduz risco de regressão, facilita code review, mantém fallback local e prepara a base para uma segunda fase, na qual conteúdos maiores poderão sair do APK de forma real para reduzir peso. A abordagem automática que alterava todos os `app_strings_*.dart` foi revertida; a continuação foi feita por uma camada nova e isolada `OtaAppStrings`, com cobertura de todos os getters e delegação dos métodos parametrizados ao fallback local. A fase atual foca primeiro em **capacidade segura de atualização remota**, não em remoção física de assets/textos do binário.
