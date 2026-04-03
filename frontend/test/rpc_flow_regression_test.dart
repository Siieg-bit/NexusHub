import 'package:flutter_test/flutter_test.dart';

/// ============================================================================
/// Testes de Regressão — Fluxos RPC / Funcionalidades Latentes
///
/// Cobrem a lógica de contrato dos fluxos alterados recentemente:
/// - edição de posts via RPC edit_post
/// - desbloqueio de conquistas via RPC check_achievements
/// - aceitação de convites de comunidade via RPC accept_invite
///
/// A estratégia segue o padrão já usado no projeto: testar lógica pura,
/// sem depender de backend real, widgets ou plugins externos.
/// ============================================================================

Map<String, dynamic> _buildEditPostRpcParams({
  required String postId,
  required String title,
  required String content,
}) {
  final trimmedTitle = title.trim();
  final trimmedContent = content.trim();

  return {
    'p_post_id': postId,
    'p_title': trimmedTitle.isNotEmpty ? trimmedTitle : null,
    'p_content': trimmedContent,
  };
}

Set<String> _extractUnlockedAchievementIds(List<Map<String, dynamic>> rows) {
  return rows
      .map((row) => (row['achievement_id'] as String?) ?? '')
      .where((id) => id.isNotEmpty)
      .toSet();
}

Map<String, int> _buildAchievementProgressMap(List<Map<String, dynamic>> rows) {
  return {
    for (final row in rows)
      if ((row['achievement_id'] as String?)?.isNotEmpty == true)
        row['achievement_id'] as String: 100,
  };
}

Map<String, dynamic> _notificationPayload(Map<String, dynamic> notification) {
  final payload = notification['data'];
  if (payload is Map) {
    return Map<String, dynamic>.from(payload);
  }
  return <String, dynamic>{};
}

String? _extractInviteCode(Map<String, dynamic> notification) {
  final payload = _notificationPayload(notification);
  final inviteCode = payload['invite_code'] as String?;
  if (inviteCode == null || inviteCode.trim().isEmpty) return null;
  return inviteCode.trim();
}

String? _extractCommunityId(Map<String, dynamic> notification) {
  final payload = _notificationPayload(notification);
  return notification['community_id'] as String? ?? payload['community_id'] as String?;
}

String _resolveInviteFeedbackMessage(String? error) {
  if (error == null) return 'Convite aceito com sucesso!';
  if (error == 'already_member') return 'Você já faz parte desta comunidade.';
  if (error == 'invalid_invite_code') return 'Este convite é inválido ou expirou.';
  if (error == 'not_authenticated') return 'Faça login para aceitar o convite.';
  return 'Não foi possível aceitar o convite agora.';
}

bool _shouldShowAcceptInviteAction(Map<String, dynamic> notification) {
  return notification['type'] == 'community_invite' &&
      _extractInviteCode(notification) != null;
}

Map<String, dynamic> _buildCreateCommunityRpcParams({
  required String name,
  required String tagline,
  required String description,
  required String themeColor,
  required String primaryLanguage,
}) {
  return {
    'p_name': name.trim(),
    'p_tagline': tagline.trim(),
    'p_description': description.trim(),
    'p_category': 'general',
    'p_join_type': 'open',
    'p_theme_color': themeColor,
    'p_primary_language': primaryLanguage,
  };
}

String _resolveCreateCommunityErrorMessage(String? error) {
  return switch (error) {
    'unauthenticated' => 'Você precisa estar logado para criar uma comunidade.',
    'name_required' => 'O nome da comunidade é obrigatório.',
    _ => 'Erro ao criar comunidade. Tente novamente.',
  };
}

class _PollVoteState {
  final int? selectedOption;
  final bool hasVoted;
  final int totalVotes;
  final List<Map<String, dynamic>> options;

  const _PollVoteState({
    required this.selectedOption,
    required this.hasVoted,
    required this.totalVotes,
    required this.options,
  });
}

_PollVoteState _resolvePollVoteSuccess({
  required _PollVoteState current,
  required int selectedIndex,
  required int? serverTotalVotes,
  required int? serverOptionVotes,
}) {
  final updatedOptions = current.options
      .map((option) => Map<String, dynamic>.from(option))
      .toList();

  if (serverOptionVotes != null) {
    updatedOptions[selectedIndex]['votes_count'] = serverOptionVotes;
  }

  return _PollVoteState(
    selectedOption: current.selectedOption,
    hasVoted: current.hasVoted,
    totalVotes: serverTotalVotes ?? current.totalVotes,
    options: updatedOptions,
  );
}

_PollVoteState _resolvePollAlreadyVoted({
  required int attemptedIndex,
  required List<Map<String, dynamic>> previousOptions,
  required String? serverOptionId,
  required int? serverTotalVotes,
}) {
  final selectedIndex = serverOptionId == null
      ? attemptedIndex
      : previousOptions.indexWhere((option) => option['id'] == serverOptionId);

  return _PollVoteState(
    selectedOption: selectedIndex >= 0 ? selectedIndex : attemptedIndex,
    hasVoted: true,
    totalVotes: serverTotalVotes ?? 0,
    options: previousOptions
        .map((option) => Map<String, dynamic>.from(option))
        .toList(),
  );
}

_PollVoteState _rollbackPollVote({
  required int? previousSelectedOption,
  required bool previousHasVoted,
  required int previousTotalVotes,
  required List<Map<String, dynamic>> previousOptions,
}) {
  return _PollVoteState(
    selectedOption: previousSelectedOption,
    hasVoted: previousHasVoted,
    totalVotes: previousTotalVotes,
    options: previousOptions
        .map((option) => Map<String, dynamic>.from(option))
        .toList(),
  );
}

void main() {
  group('edit_post RPC contract', () {
    test('envia título aparado quando preenchido', () {
      final params = _buildEditPostRpcParams(
        postId: 'post-1',
        title: '  Novo título  ',
        content: '  Conteúdo atualizado  ',
      );

      expect(params['p_post_id'], equals('post-1'));
      expect(params['p_title'], equals('Novo título'));
      expect(params['p_content'], equals('Conteúdo atualizado'));
    });

    test('envia título nulo quando campo fica vazio após trim', () {
      final params = _buildEditPostRpcParams(
        postId: 'post-1',
        title: '   ',
        content: 'Texto válido',
      );

      expect(params['p_title'], isNull);
      expect(params['p_content'], equals('Texto válido'));
    });
  });

  group('create_community RPC contract', () {
    test('envia payload padrão esperado pela RPC', () {
      final params = _buildCreateCommunityRpcParams(
        name: '  Comunidade BR  ',
        tagline: '  Bem-vindos  ',
        description: '  Descrição da comunidade  ',
        themeColor: '#6C5CE7',
        primaryLanguage: 'pt-BR',
      );

      expect(params, equals({
        'p_name': 'Comunidade BR',
        'p_tagline': 'Bem-vindos',
        'p_description': 'Descrição da comunidade',
        'p_category': 'general',
        'p_join_type': 'open',
        'p_theme_color': '#6C5CE7',
        'p_primary_language': 'pt-BR',
      }));
    });

    test('resolve mensagens de erro compatíveis com a tela', () {
      expect(
        _resolveCreateCommunityErrorMessage('unauthenticated'),
        equals('Você precisa estar logado para criar uma comunidade.'),
      );
      expect(
        _resolveCreateCommunityErrorMessage('name_required'),
        equals('O nome da comunidade é obrigatório.'),
      );
      expect(
        _resolveCreateCommunityErrorMessage('qualquer_outro_erro'),
        equals('Erro ao criar comunidade. Tente novamente.'),
      );
    });
  });

  group('check_achievements sync logic', () {
    test('extrai apenas IDs válidos das conquistas desbloqueadas', () {
      final unlockedIds = _extractUnlockedAchievementIds([
        {'achievement_id': 'a1'},
        {'achievement_id': ''},
        {'achievement_id': null},
        {'achievement_id': 'a2'},
      ]);

      expect(unlockedIds, equals({'a1', 'a2'}));
    });

    test('marca progresso completo apenas para conquistas válidas', () {
      final progressMap = _buildAchievementProgressMap([
        {'achievement_id': 'a1'},
        {'achievement_id': ''},
        {'achievement_id': 'a2'},
      ]);

      expect(progressMap, equals({'a1': 100, 'a2': 100}));
    });
  });

  group('vote_on_poll reconciliation logic', () {
    test('aplica totais retornados pelo servidor em caso de sucesso', () {
      final state = _resolvePollVoteSuccess(
        current: const _PollVoteState(
          selectedOption: 1,
          hasVoted: true,
          totalVotes: 4,
          options: [
            {'id': 'o1', 'votes_count': 1},
            {'id': 'o2', 'votes_count': 3},
          ],
        ),
        selectedIndex: 1,
        serverTotalVotes: 10,
        serverOptionVotes: 7,
      );

      expect(state.totalVotes, equals(10));
      expect(state.options[1]['votes_count'], equals(7));
      expect(state.selectedOption, equals(1));
      expect(state.hasVoted, isTrue);
    });

    test('reconcilia already_voted com opção retornada pelo backend', () {
      final state = _resolvePollAlreadyVoted(
        attemptedIndex: 0,
        previousOptions: const [
          {'id': 'o1', 'votes_count': 4},
          {'id': 'o2', 'votes_count': 6},
        ],
        serverOptionId: 'o2',
        serverTotalVotes: 10,
      );

      expect(state.selectedOption, equals(1));
      expect(state.hasVoted, isTrue);
      expect(state.totalVotes, equals(10));
      expect(state.options[0]['votes_count'], equals(4));
      expect(state.options[1]['votes_count'], equals(6));
    });

    test('faz rollback completo em caso de falha', () {
      final state = _rollbackPollVote(
        previousSelectedOption: null,
        previousHasVoted: false,
        previousTotalVotes: 8,
        previousOptions: const [
          {'id': 'o1', 'votes_count': 3},
          {'id': 'o2', 'votes_count': 5},
        ],
      );

      expect(state.selectedOption, isNull);
      expect(state.hasVoted, isFalse);
      expect(state.totalVotes, equals(8));
      expect(state.options[0]['votes_count'], equals(3));
      expect(state.options[1]['votes_count'], equals(5));
    });
  });

  group('accept_invite notification flow', () {
    test('extrai invite_code do payload data', () {
      final inviteCode = _extractInviteCode({
        'type': 'community_invite',
        'data': {'invite_code': '  ABC123  '},
      });

      expect(inviteCode, equals('ABC123'));
    });

    test('retorna nulo quando invite_code não existe', () {
      final inviteCode = _extractInviteCode({
        'type': 'community_invite',
        'data': {'community_id': 'community-1'},
      });

      expect(inviteCode, isNull);
    });

    test('usa community_id top-level como fallback', () {
      final communityId = _extractCommunityId({
        'type': 'community_invite',
        'community_id': 'community-top-level',
        'data': {'community_id': 'community-payload'},
      });

      expect(communityId, equals('community-top-level'));
    });

    test('usa community_id do payload quando top-level não existe', () {
      final communityId = _extractCommunityId({
        'type': 'community_invite',
        'data': {'community_id': 'community-payload'},
      });

      expect(communityId, equals('community-payload'));
    });

    test('mostra ação de aceitar apenas quando há invite_code utilizável', () {
      expect(
        _shouldShowAcceptInviteAction({
          'type': 'community_invite',
          'data': {'invite_code': 'code-1'},
        }),
        isTrue,
      );

      expect(
        _shouldShowAcceptInviteAction({
          'type': 'community_invite',
          'data': {'community_id': 'community-1'},
        }),
        isFalse,
      );

      expect(
        _shouldShowAcceptInviteAction({
          'type': 'like',
          'data': {'invite_code': 'code-1'},
        }),
        isFalse,
      );
    });

    test('resolve mensagens corretas para cada retorno da RPC', () {
      expect(_resolveInviteFeedbackMessage(null), equals('Convite aceito com sucesso!'));
      expect(
        _resolveInviteFeedbackMessage('already_member'),
        equals('Você já faz parte desta comunidade.'),
      );
      expect(
        _resolveInviteFeedbackMessage('invalid_invite_code'),
        equals('Este convite é inválido ou expirou.'),
      );
      expect(
        _resolveInviteFeedbackMessage('not_authenticated'),
        equals('Faça login para aceitar o convite.'),
      );
      expect(
        _resolveInviteFeedbackMessage('unexpected_error'),
        equals('Não foi possível aceitar o convite agora.'),
      );
    });
  });
}
