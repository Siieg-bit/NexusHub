import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

import '../../../config/app_theme.dart';
import '../../../core/services/supabase_service.dart';

// =============================================================================
// CREATE GROUP CHAT SCREEN — Estilo Amino Apps
// Fluxo: Selecionar comunidade → Nome do grupo → Selecionar membros → Criar
// =============================================================================

class CreateGroupChatScreen extends ConsumerStatefulWidget {
  const CreateGroupChatScreen({super.key});

  @override
  ConsumerState<CreateGroupChatScreen> createState() =>
      _CreateGroupChatScreenState();
}

class _CreateGroupChatScreenState extends ConsumerState<CreateGroupChatScreen> {
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _searchController = TextEditingController();

  int _currentStep = 0; // 0=comunidade, 1=info, 2=membros
  String? _selectedCommunityId;
  String? _selectedCommunityName;
  File? _coverImage;
  bool _isPublic = true;
  bool _isCreating = false;

  List<Map<String, dynamic>> _communities = [];
  List<Map<String, dynamic>> _members = [];
  List<Map<String, dynamic>> _filteredMembers = [];
  final Set<String> _selectedMemberIds = {};
  bool _isLoadingCommunities = true;
  bool _isLoadingMembers = false;

  @override
  void initState() {
    super.initState();
    _loadCommunities();
    _searchController.addListener(_filterMembers);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCommunities() async {
    try {
      final userId = SupabaseService.currentUserId;
      if (userId == null) return;
      final res = await SupabaseService.table('community_members')
          .select('community_id, communities(id, name, icon_url)')
          .eq('user_id', userId)
          .order('joined_at', ascending: false);
      if (mounted) {
        setState(() {
          _communities = (res as List)
              .where((e) => e['communities'] != null)
              .map((e) => Map<String, dynamic>.from(e['communities']))
              .toList();
          _isLoadingCommunities = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingCommunities = false);
    }
  }

  Future<void> _loadMembers() async {
    if (_selectedCommunityId == null) return;
    setState(() => _isLoadingMembers = true);
    try {
      final res = await SupabaseService.table('community_members')
          .select(
              'user_id, role, profiles!community_members_user_id_fkey(id, nickname, icon_url)')
          .eq('community_id', _selectedCommunityId!)
          .neq('user_id', SupabaseService.currentUserId ?? '')
          .order('role', ascending: false)
          .limit(100);
      if (mounted) {
        setState(() {
          _members = List<Map<String, dynamic>>.from(res as List);
          _filteredMembers = _members;
          _isLoadingMembers = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingMembers = false);
    }
  }

  void _filterMembers() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredMembers = _members;
      } else {
        _filteredMembers = _members.where((m) {
          final p = m['profiles'] as Map<String, dynamic>? ?? {};
          final name = (p['nickname'] as String? ?? '').toLowerCase();
          return name.contains(query);
        }).toList();
      }
    });
  }

  Future<void> _pickCoverImage() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 400,
      );
      if (picked != null && mounted) {
        setState(() => _coverImage = File(picked.path));
      }
    } catch (_) {}
  }

  Future<void> _createGroupChat() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Digite um nome para o grupo')),
      );
      return;
    }
    if (_selectedCommunityId == null) return;

    setState(() => _isCreating = true);
    try {
      final userId = SupabaseService.currentUserId;
      if (userId == null) throw Exception('Usuário não autenticado');

      // Upload da imagem de capa se existir
      String? coverUrl;
      if (_coverImage != null) {
        final bytes = await _coverImage!.readAsBytes();
        final fileName =
            'chat_covers/${DateTime.now().millisecondsSinceEpoch}.jpg';
        await SupabaseService.client.storage
            .from('uploads')
            .uploadBinary(fileName, bytes);
        coverUrl = SupabaseService.client.storage
            .from('uploads')
            .getPublicUrl(fileName);
      }

      // Criar o chat thread
      final threadRes =
          await SupabaseService.table('chat_threads').insert({
        'community_id': _selectedCommunityId,
        'title': _nameController.text.trim(),
        'description': _descriptionController.text.trim().isNotEmpty
            ? _descriptionController.text.trim()
            : null,
        'type': _isPublic ? 'public' : 'private',
        'created_by': userId,
        'icon_url': coverUrl,
        'members_count': _selectedMemberIds.length + 1,
      }).select().single();

      final threadId = threadRes['id'] as String;

      // Adicionar o criador como membro (host)
      await SupabaseService.table('chat_members').insert({
        'thread_id': threadId,
        'user_id': userId,
        'role': 'host',
      });

      // Adicionar membros selecionados
      if (_selectedMemberIds.isNotEmpty) {
        final memberInserts = _selectedMemberIds.map((memberId) => {
              'thread_id': threadId,
              'user_id': memberId,
              'role': 'member',
            }).toList();
        await SupabaseService.table('chat_members').insert(memberInserts);
      }

      // Mensagem de sistema
      await SupabaseService.table('chat_messages').insert({
        'thread_id': threadId,
        'sender_id': userId,
        'content': 'Grupo criado',
        'type': 19, // system message
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Grupo criado com sucesso!'),
            backgroundColor: AppTheme.primaryColor,
            behavior: SnackBarBehavior.floating,
          ),
        );
        context.go('/chat/$threadId');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao criar grupo: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isCreating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.scaffoldBg,
      appBar: AppBar(
        backgroundColor: context.scaffoldBg,
        elevation: 0,
        title: const Text(
          'Criar Grupo',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: context.textPrimary,
            fontSize: 18,
          ),
        ),
        iconTheme: IconThemeData(color: context.textPrimary),
        actions: [
          if (_currentStep == 2)
            TextButton(
              onPressed: _isCreating ? null : _createGroupChat,
              child: _isCreating
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppTheme.primaryColor),
                    )
                  : const Text(
                      'Criar',
                      style: TextStyle(
                        color: AppTheme.primaryColor,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
            ),
        ],
      ),
      body: Column(
        children: [
          // Step indicator
          _buildStepIndicator(),

          // Content
          Expanded(
            child: _currentStep == 0
                ? _buildCommunityStep()
                : _currentStep == 1
                    ? _buildInfoStep()
                    : _buildMembersStep(),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // STEP INDICATOR
  // ==========================================================================
  Widget _buildStepIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        children: [
          _buildStepDot(0, 'Comunidade'),
          _buildStepLine(0),
          _buildStepDot(1, 'Info'),
          _buildStepLine(1),
          _buildStepDot(2, 'Membros'),
        ],
      ),
    );
  }

  Widget _buildStepDot(int step, String label) {
    final isActive = _currentStep >= step;
    final isCurrent = _currentStep == step;
    return Column(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: isCurrent ? 32 : 24,
          height: isCurrent ? 32 : 24,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isActive ? AppTheme.primaryColor : context.surfaceColor,
            border: Border.all(
              color: isActive
                  ? AppTheme.primaryColor
                  : Colors.grey[700]!,
              width: 2,
            ),
            boxShadow: isCurrent
                ? [
                    BoxShadow(
                      color: AppTheme.primaryColor.withValues(alpha: 0.3),
                      blurRadius: 8,
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: Text(
              '${step + 1}',
              style: TextStyle(
                color: isActive ? Colors.white : Colors.grey[600],
                fontWeight: FontWeight.w800,
                fontSize: isCurrent ? 14 : 11,
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: isActive ? context.textPrimary : Colors.grey[600],
            fontSize: 10,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ],
    );
  }

  Widget _buildStepLine(int afterStep) {
    final isActive = _currentStep > afterStep;
    return Expanded(
      child: Container(
        height: 2,
        margin: const EdgeInsets.only(bottom: 16),
        color: isActive ? AppTheme.primaryColor : Colors.grey[800],
      ),
    );
  }

  // ==========================================================================
  // STEP 0: SELECIONAR COMUNIDADE
  // ==========================================================================
  Widget _buildCommunityStep() {
    if (_isLoadingCommunities) {
      return const Center(
        child: CircularProgressIndicator(
            color: AppTheme.primaryColor, strokeWidth: 2),
      );
    }

    if (_communities.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.groups_rounded, size: 48, color: Colors.grey[600]),
            const SizedBox(height: 12),
            Text('Nenhuma comunidade encontrada',
                style: TextStyle(color: Colors.grey[500])),
            const SizedBox(height: 8),
            Text('Entre em uma comunidade primeiro',
                style: TextStyle(color: Colors.grey[600], fontSize: 12)),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Selecione a comunidade para o grupo:',
          style: TextStyle(
            color: Colors.grey[400],
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 16),
        ..._communities.map((community) {
          final id = community['id'] as String;
          final name = community['name'] as String? ?? 'Comunidade';
          final iconUrl = community['icon_url'] as String?;
          final isSelected = _selectedCommunityId == id;

          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedCommunityId = id;
                _selectedCommunityName = name;
              });
              // Avançar automaticamente
              Future.delayed(const Duration(milliseconds: 200), () {
                if (mounted) {
                  setState(() => _currentStep = 1);
                }
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppTheme.primaryColor.withValues(alpha: 0.15)
                    : context.surfaceColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected
                      ? AppTheme.primaryColor
                      : Colors.white.withValues(alpha: 0.08),
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: context.cardBg,
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: iconUrl != null
                        ? CachedNetworkImage(
                            imageUrl: iconUrl, fit: BoxFit.cover)
                        : Icon(Icons.groups_rounded,
                            color: context.textHint, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      name,
                      style: TextStyle(
                        color: context.textPrimary,
                        fontWeight:
                            isSelected ? FontWeight.w700 : FontWeight.w500,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  if (isSelected)
                    const Icon(Icons.check_circle_rounded,
                        color: AppTheme.primaryColor, size: 22),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  // ==========================================================================
  // STEP 1: INFO DO GRUPO (nome, descricao, imagem, publico/privado)
  // ==========================================================================
  Widget _buildInfoStep() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Cover image
        GestureDetector(
          onTap: _pickCoverImage,
          child: Container(
            height: 140,
            decoration: BoxDecoration(
              color: context.surfaceColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.08),
              ),
              image: _coverImage != null
                  ? DecorationImage(
                      image: FileImage(_coverImage!),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: _coverImage == null
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_photo_alternate_rounded,
                          size: 36, color: Colors.grey[600]),
                      const SizedBox(height: 8),
                      Text('Adicionar capa (opcional)',
                          style:
                              TextStyle(color: Colors.grey[600], fontSize: 13)),
                    ],
                  )
                : null,
          ),
        ),
        const SizedBox(height: 20),

        // Nome do grupo
        Text('Nome do Grupo *',
            style: TextStyle(
                color: Colors.grey[400],
                fontSize: 13,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        TextField(
          controller: _nameController,
          style: TextStyle(color: context.textPrimary, fontSize: 16),
          decoration: InputDecoration(
            hintText: 'Ex: Fan Club do Anime',
            hintStyle: TextStyle(color: Colors.grey[600]),
            filled: true,
            fillColor: context.surfaceColor,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
        const SizedBox(height: 20),

        // Descricao
        Text('Descricao (opcional)',
            style: TextStyle(
                color: Colors.grey[400],
                fontSize: 13,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        TextField(
          controller: _descriptionController,
          style: TextStyle(color: context.textPrimary, fontSize: 14),
          maxLines: 3,
          decoration: InputDecoration(
            hintText: 'Descreva o grupo...',
            hintStyle: TextStyle(color: Colors.grey[600]),
            filled: true,
            fillColor: context.surfaceColor,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
        const SizedBox(height: 20),

        // Publico/Privado toggle
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: context.surfaceColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(
                _isPublic ? Icons.public_rounded : Icons.lock_rounded,
                color: _isPublic ? AppTheme.primaryColor : Colors.orange,
                size: 22,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _isPublic ? 'Chat Publico' : 'Chat Privado',
                      style: TextStyle(
                        color: context.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      _isPublic
                          ? 'Qualquer membro da comunidade pode entrar'
                          : 'Apenas membros convidados podem entrar',
                      style: TextStyle(color: Colors.grey[500], fontSize: 11),
                    ),
                  ],
                ),
              ),
              Switch(
                value: _isPublic,
                onChanged: (v) => setState(() => _isPublic = v),
                activeColor: AppTheme.primaryColor,
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Comunidade selecionada
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              const Icon(Icons.groups_rounded,
                  color: AppTheme.primaryColor, size: 18),
              const SizedBox(width: 8),
              Text(
                'Comunidade: $_selectedCommunityName',
                style: const TextStyle(
                  color: AppTheme.primaryColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => setState(() => _currentStep = 0),
                child: const Text('Alterar',
                    style: TextStyle(
                        color: AppTheme.accentColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Botao avancar
        GestureDetector(
          onTap: () {
            if (_nameController.text.trim().isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Digite um nome para o grupo')),
              );
              return;
            }
            setState(() => _currentStep = 2);
            _loadMembers();
          },
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppTheme.primaryColor, AppTheme.accentColor],
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryColor.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: const Center(
              child: Text(
                'Selecionar Membros',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ==========================================================================
  // STEP 2: SELECIONAR MEMBROS
  // ==========================================================================
  Widget _buildMembersStep() {
    return Column(
      children: [
        // Search bar
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: TextField(
            controller: _searchController,
            style: TextStyle(color: context.textPrimary, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Buscar membros...',
              hintStyle: TextStyle(color: Colors.grey[600]),
              prefixIcon:
                  Icon(Icons.search_rounded, color: Colors.grey[600], size: 20),
              filled: true,
              fillColor: context.surfaceColor,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
          ),
        ),

        // Selected count
        if (_selectedMemberIds.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${_selectedMemberIds.length} selecionado(s)',
                    style: const TextStyle(
                      color: AppTheme.primaryColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => setState(() => _selectedMemberIds.clear()),
                  child: Text('Limpar',
                      style: TextStyle(
                          color: Colors.grey[500],
                          fontSize: 12,
                          fontWeight: FontWeight.w500)),
                ),
              ],
            ),
          ),

        // Members list
        Expanded(
          child: _isLoadingMembers
              ? const Center(
                  child: CircularProgressIndicator(
                      color: AppTheme.primaryColor, strokeWidth: 2),
                )
              : _filteredMembers.isEmpty
                  ? Center(
                      child: Text('Nenhum membro encontrado',
                          style: TextStyle(color: Colors.grey[500])),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _filteredMembers.length,
                      itemBuilder: (context, index) {
                        final member = _filteredMembers[index];
                        final profile =
                            member['profiles'] as Map<String, dynamic>? ?? {};
                        final userId = profile['id'] as String? ??
                            member['user_id'] as String? ??
                            '';
                        final nickname =
                            profile['nickname'] as String? ?? 'Usuario';
                        final avatarUrl = profile['icon_url'] as String?;
                        final role = member['role'] as String? ?? 'member';
                        final isSelected = _selectedMemberIds.contains(userId);

                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              if (isSelected) {
                                _selectedMemberIds.remove(userId);
                              } else {
                                _selectedMemberIds.add(userId);
                              }
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              border: Border(
                                bottom: BorderSide(
                                  color: Colors.white.withValues(alpha: 0.05),
                                  width: 0.5,
                                ),
                              ),
                            ),
                            child: Row(
                              children: [
                                // Checkbox
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  width: 22,
                                  height: 22,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: isSelected
                                        ? AppTheme.primaryColor
                                        : Colors.transparent,
                                    border: Border.all(
                                      color: isSelected
                                          ? AppTheme.primaryColor
                                          : Colors.grey[600]!,
                                      width: 2,
                                    ),
                                  ),
                                  child: isSelected
                                      ? const Icon(Icons.check_rounded,
                                          color: Colors.white, size: 14)
                                      : null,
                                ),
                                const SizedBox(width: 12),
                                // Avatar
                                CircleAvatar(
                                  radius: 20,
                                  backgroundColor: AppTheme.primaryColor
                                      .withValues(alpha: 0.2),
                                  backgroundImage: avatarUrl != null
                                      ? CachedNetworkImageProvider(avatarUrl)
                                      : null,
                                  child: avatarUrl == null
                                      ? Text(
                                          nickname[0].toUpperCase(),
                                          style: const TextStyle(
                                            color: AppTheme.primaryColor,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        )
                                      : null,
                                ),
                                const SizedBox(width: 12),
                                // Info
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        nickname,
                                        style: TextStyle(
                                          color: context.textPrimary,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14,
                                        ),
                                      ),
                                      if (role != 'member')
                                        Container(
                                          margin: const EdgeInsets.only(top: 2),
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 6, vertical: 1),
                                          decoration: BoxDecoration(
                                            color: role == 'leader'
                                                ? Colors.amber
                                                    .withValues(alpha: 0.2)
                                                : AppTheme.primaryColor
                                                    .withValues(alpha: 0.2),
                                            borderRadius:
                                                BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            role == 'leader'
                                                ? 'Leader'
                                                : role == 'curator'
                                                    ? 'Curator'
                                                    : role,
                                            style: TextStyle(
                                              color: role == 'leader'
                                                  ? Colors.amber
                                                  : AppTheme.primaryColor,
                                              fontSize: 10,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }
}
