# Guia de Testes - NexusHub v1.1.0

## 🧪 Estratégia de Testes

Este documento descreve como testar todas as funcionalidades implementadas na v1.1.0.

---

## 1. Quiz System (B1)

### Teste Manual

1. Navegar para uma comunidade
2. Criar um novo post com tipo "Quiz"
3. Adicionar 3-4 questões com múltiplas respostas
4. Publicar o quiz
5. Responder o quiz como usuário diferente
6. Verificar se a resposta é salva no banco

### Teste Automatizado

```dart
test('Quiz answer should be persisted', () async {
  // Arrange
  final quizId = 'test-quiz-id';
  final optionId = 'option-1';
  
  // Act
  final result = await SupabaseService.rpc('answer_quiz', params: {
    'p_quiz_id': quizId,
    'p_option_id': optionId,
  });
  
  // Assert
  expect(result['success'], true);
  expect(result['votes_updated'], true);
});
```

### Verificações

- [ ] Resposta é salva em `quiz_answers`
- [ ] Contador de votos é incrementado
- [ ] Usuário não pode votar duas vezes
- [ ] Histórico de respostas é recuperável
- [ ] UI mostra resposta anterior do usuário

---

## 2. Wiki System (B2)

### Teste Manual

1. Navegar para seção Wiki
2. Criar novo artigo
3. Adicionar título, conteúdo e tags
4. Publicar artigo
5. Verificar se artigo aparece na lista
6. Editar artigo
7. Deletar artigo

### Teste Automatizado

```dart
test('Wiki entry should be created and published', () async {
  // Arrange
  final wikiData = {
    'title': 'Test Article',
    'content': 'Test content',
    'tags': ['test', 'wiki'],
  };
  
  // Act
  final result = await SupabaseService.rpc('create_wiki_entry', params: {
    'p_title': wikiData['title'],
    'p_content': wikiData['content'],
    'p_tags': wikiData['tags'],
  });
  
  // Assert
  expect(result['success'], true);
  expect(result['wiki_id'], isNotNull);
});
```

### Verificações

- [ ] Artigo é salvo em `posts` com tipo `wiki`
- [ ] `wiki_data` é preenchido corretamente
- [ ] Artigo aparece na lista de wiki
- [ ] Edição atualiza conteúdo
- [ ] Deleção remove artigo
- [ ] Validação de conteúdo funciona

---

## 3. Chat Forms (B3)

### Teste Manual

1. Abrir chat de comunidade
2. Criar formulário com 4 tipos de campos:
   - Text input
   - Number input
   - Select dropdown
   - Checkbox
3. Enviar formulário
4. Responder formulário como outro usuário
5. Verificar respostas

### Teste Automatizado

```dart
test('Chat form should be created and responded', () async {
  // Arrange
  final formData = {
    'fields': [
      {'type': 'text', 'label': 'Name'},
      {'type': 'select', 'label': 'Option', 'options': ['A', 'B']},
    ],
  };
  
  // Act
  final result = await SupabaseService.rpc('create_chat_form', params: {
    'p_thread_id': 'thread-id',
    'p_form_data': formData,
  });
  
  // Assert
  expect(result['success'], true);
  expect(result['form_id'], isNotNull);
});
```

### Verificações

- [ ] Tipo `form` existe no enum `chat_message_type`
- [ ] Formulário é renderizado corretamente
- [ ] Todos os 4 tipos de campos funcionam
- [ ] Validação de resposta funciona
- [ ] Respostas são salvas em `chat_form_responses`

---

## 4. Drafts System (B4)

### Teste Manual

1. Criar novo post
2. Escrever conteúdo
3. Salvar como rascunho com nome
4. Criar segundo rascunho com outro nome
5. Listar rascunhos
6. Editar rascunho
7. Auto-save deve funcionar a cada 30 segundos
8. Deletar rascunho

### Teste Automatizado

```dart
test('Multiple drafts should be saved and retrieved', () async {
  // Arrange
  final draft1 = {'name': 'Draft 1', 'content': 'Content 1'};
  final draft2 = {'name': 'Draft 2', 'content': 'Content 2'};
  
  // Act
  final result1 = await SupabaseService.rpc('save_draft', params: {
    'p_draft_name': draft1['name'],
    'p_content': draft1['content'],
  });
  
  final result2 = await SupabaseService.rpc('save_draft', params: {
    'p_draft_name': draft2['name'],
    'p_content': draft2['content'],
  });
  
  final drafts = await SupabaseService.rpc('get_drafts');
  
  // Assert
  expect(drafts['drafts'].length, greaterThanOrEqualTo(2));
});
```

### Verificações

- [ ] Múltiplos rascunhos podem ser salvos
- [ ] Cada rascunho tem nome único
- [ ] Auto-save funciona a cada 30 segundos
- [ ] Rascunhos são listados corretamente
- [ ] Edição atualiza rascunho
- [ ] Deleção remove rascunho
- [ ] Recuperação de rascunho funciona

---

## 5. Community Visuals (B5-B7)

### Teste Manual - Capa

1. Ir para configurações de comunidade
2. Fazer upload de imagem de capa
3. Selecionar posição (center, top, bottom)
4. Ativar desfoque
5. Ajustar opacidade
6. Salvar

### Teste Manual - Cores

1. Abrir color picker
2. Selecionar cor primária
3. Selecionar cor de destaque
4. Selecionar cor secundária
5. Verificar preview
6. Salvar

### Teste Manual - Minhas Comunidades

1. Criar nova comunidade
2. Entrar em comunidade existente
3. Abrir "Minhas Comunidades"
4. Verificar se comunidades criadas aparecem
5. Verificar se comunidades onde é membro aparecem

### Teste Automatizado

```dart
test('Community visuals should be updated', () async {
  // Arrange
  final communityId = 'community-id';
  
  // Act
  final result = await SupabaseService.rpc('update_community_visuals', params: {
    'p_community_id': communityId,
    'p_cover_image_url': 'https://example.com/cover.jpg',
    'p_theme_primary_color': '#FF6B6B',
  });
  
  // Assert
  expect(result['success'], true);
});
```

### Verificações

- [ ] Capa é salva e exibida
- [ ] Posição da capa funciona
- [ ] Desfoque é aplicado
- [ ] Opacidade é ajustável
- [ ] Cores são validadas (formato hex)
- [ ] Preview é atualizado em tempo real
- [ ] "Minhas Comunidades" mostra criadas e membros

---

## 6. Smart Links (M1-M6)

### Teste Manual - Detecção

1. Postar mensagem com link externo
2. Postar mensagem com link interno (/post/id)
3. Verificar se tipo é detectado corretamente
4. Verificar preview do link

### Teste Manual - Preview

1. Abrir chat
2. Enviar mensagem com link
3. Verificar se preview aparece
4. Verificar thumbnail, título, descrição
5. Clicar no link
6. Verificar se clique é registrado

### Teste Manual - Edição

1. Abrir preview de link
2. Clicar em editar
3. Customizar título
4. Customizar descrição
5. Salvar
6. Verificar se alterações aparecem

### Teste Automatizado

```dart
test('Link should be detected and saved', () async {
  // Arrange
  final url = 'https://example.com/article';
  
  // Act
  final result = await SupabaseService.rpc('detect_and_save_link', params: {
    'p_url': url,
    'p_usage_context': 'message',
  });
  
  // Assert
  expect(result['success'], true);
  expect(result['link_type'], 'external');
});
```

### Verificações

- [ ] Links externos são detectados
- [ ] Links internos são detectados
- [ ] Preview é exibido corretamente
- [ ] Metadados são salvos
- [ ] Título e descrição podem ser customizados
- [ ] Cliques são registrados
- [ ] Links populares são listados

---

## 7. Quick Stickers (M7)

### Teste Manual

1. Abrir chat
2. Clicar em botão de figurinha
3. Selecionar imagem da galeria
4. Verificar preview
5. Digitar nome da figurinha
6. Enviar
7. Verificar se figurinha aparece no chat

### Teste Automatizado

```dart
test('Sticker should be created and sent', () async {
  // Arrange
  final threadId = 'thread-id';
  
  // Act
  await SupabaseService.table('chat_messages').insert({
    'thread_id': threadId,
    'type': 'sticker',
    'sticker_url': 'https://example.com/sticker.png',
    'content': 'My Sticker',
  });
  
  // Assert
  // Verificar se mensagem foi inserida
});
```

### Verificações

- [ ] Upload de imagem funciona
- [ ] Compressão é aplicada (max 512x512)
- [ ] Preview é exibido
- [ ] Figurinha é enviada
- [ ] Figurinha aparece no chat
- [ ] Histórico de figurinhas é mantido

---

## 8. Quick Polls (M8)

### Teste Manual - Votação

1. Abrir feed
2. Encontrar enquete
3. Clicar em opção para votar
4. Verificar se voto é registrado
5. Verificar se percentual é atualizado
6. Tentar votar novamente (deve ser bloqueado)

### Teste Manual - Criação

1. Clicar em criar enquete
2. Digitar pergunta
3. Adicionar 3 opções
4. Clicar em "Adicionar Opção"
5. Remover uma opção
6. Criar enquete
7. Verificar se aparece no feed

### Teste Automatizado

```dart
test('Poll vote should be registered', () async {
  // Arrange
  final optionId = 'option-id';
  
  // Act
  await SupabaseService.table('poll_votes').insert({
    'option_id': optionId,
    'user_id': SupabaseService.currentUserId,
  });
  
  // Assert
  // Verificar se voto foi inserido
});
```

### Verificações

- [ ] Votação com um toque funciona
- [ ] Percentual é calculado corretamente
- [ ] Barra de progresso é exibida
- [ ] Usuário não pode votar duas vezes
- [ ] Enquete pode ser criada com 2-5 opções
- [ ] Percentuais são atualizados em tempo real

---

## 🔍 Testes de Integração

### Executar Testes

```bash
# Todos os testes
flutter test

# Testes específicos
flutter test test/features/quiz/
flutter test test/features/chat/
flutter test test/features/feed/
flutter test test/features/communities/

# Com coverage
flutter test --coverage
```

### Coverage Esperado

- Quiz: 85%+
- Chat: 80%+
- Feed: 85%+
- Communities: 80%+
- Geral: 82%+

---

## 📊 Testes de Performance

### Executar Profiling

```bash
flutter run --profile

# Ou com DevTools
flutter pub global activate devtools
devtools
```

### Métricas Esperadas

- Build time: < 2s
- Frame rate: 60 fps
- Memory: < 150 MB
- Startup time: < 3s

---

## 🔐 Testes de Segurança

### Verificações

- [ ] RLS policies estão ativas
- [ ] Usuários não podem acessar dados de outros
- [ ] RPCs validam entrada
- [ ] Sem SQL injection possível
- [ ] Sem XSS possível
- [ ] Tokens são seguros

### Executar

```bash
# Verificar RLS
SELECT * FROM auth.users WHERE id != auth.uid();
-- Deve retornar erro

# Verificar policies
SELECT * FROM pg_policies WHERE schemaname = 'public';
```

---

## ✅ Checklist Final

- [ ] Todos os 4 bugs corrigidos
- [ ] Todas as 6 novas funcionalidades funcionam
- [ ] Testes unitários passando (82%+ coverage)
- [ ] Testes de integração passando
- [ ] Performance dentro dos limites
- [ ] Segurança auditada
- [ ] Documentação completa
- [ ] Pronto para produção

---

## 📞 Troubleshooting

### Teste falha com erro de autenticação

```dart
// Fazer login antes do teste
await SupabaseService.signIn(email, password);
```

### Teste falha com erro de RPC não encontrada

```bash
# Verificar se migration foi aplicada
supabase migration list
```

### Teste falha com timeout

```dart
// Aumentar timeout
testWidgets('...', (WidgetTester tester) async {
  tester.binding.window.physicalSizeTestValue = Size(800, 600);
  addTearDown(tester.binding.window.clearPhysicalSizeTestValue);
}, timeout: Timeout(Duration(seconds: 30)));
```

---

**Data**: 13 de Abril de 2026
**Versão**: 1.0.0
**Status**: Pronto para Testes 🧪
