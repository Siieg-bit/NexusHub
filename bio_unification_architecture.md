# Arquitetura proposta para bio unificada

## Objetivo
Unificar a bio global e a bio da comunidade em um mesmo módulo reutilizável de **edição** e **renderização**, preservando o contexto de persistência de cada uma.

## Decisões
1. O conteúdo da bio continuará sendo salvo no mesmo campo textual já existente em cada contexto:
   - `user.bio` para a bio global.
   - `local_bio` / campo equivalente do perfil local na comunidade para a bio da comunidade.
2. Para evitar migrações de banco, o conteúdo passará a aceitar dois formatos:
   - **legado**: Markdown simples já existente.
   - **novo**: documento JSON serializado em string, com blocos de texto e mídia.
3. O renderer compartilhado fará detecção automática:
   - Se a string for JSON válido do documento de bio, renderiza blocos ricos.
   - Caso contrário, trata como Markdown legado.
4. O editor compartilhado será um modal reutilizável, com:
   - barra de formatação;
   - seleção de cor de texto;
   - inserção de imagem, GIF e vídeo;
   - pré-visualização ao vivo;
   - serialização do documento.
5. A mídia será enviada pelo fluxo já existente de upload para storage, aproveitando o serviço central de mídia.
6. O comportamento específico de cada bio ficará só na camada chamadora:
   - título do modal;
   - texto de ajuda;
   - callback de salvar;
   - campo persistido.

## Estrutura sugerida
Criar componentes compartilhados em `frontend/lib/features/profile/widgets/`:

- `rich_bio_models.dart`
  - modelos do documento (`RichBioDocument`, `RichBioBlock`, etc.).
- `rich_bio_codec.dart`
  - parse, serialização, compatibilidade com markdown legado.
- `rich_bio_renderer.dart`
  - widget único de renderização para bio global e bio da comunidade.
- `rich_bio_editor_sheet.dart`
  - modal compartilhado de edição.

## Integrações previstas
Atualizar os pontos de uso para empregar o renderer/editor compartilhado:
- perfil global;
- edição de perfil global;
- perfil da comunidade;
- tela de bio e mural da comunidade;
- edição de perfil da comunidade.

## Observações
- A bio global e a bio da comunidade continuarão separadas; apenas o módulo será compartilhado.
- O renderer deve aceitar links e mídias sem quebrar bios antigas.
- O modal da comunidade atual servirá como base do componente compartilhado, com extensão para cor de texto e mídia local.
