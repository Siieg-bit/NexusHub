import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

import '../../../config/app_theme.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/l10n/locale_provider.dart';
import 'package:amino_clone/config/nexus_theme_extension.dart';

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
          _communities = (res as List? ?? [])
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
          _members = List<Map<String, dynamic>>.from(res as List? ?? []);
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
    final r = context.r;
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: r.w(800),
        maxHeight: 400,
      );
      if (picked != null && mounted) {
        setState(() => _coverImage = File(picked.path));
      }
    } catch (e) {
      debugPrint('[create_group_chat_screen] Erro: $e');
    }
  }

  Future<void> _createGroupChat() async {
    final s = getStrings();
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.enterGroupName)),
      );
      return;
    }
    if (_selectedCommunityId == null) return;

    setState(() => _isCreating = true);
    try {
      final userId = SupabaseService.currentUserId;
      if (userId == null) throw Exception(s.userNotAuthenticated);

      // Upload da imagem de capa se existir
      String? coverUrl;
      if (_coverImage != null) {
        final bytes = await _coverImage!.readAsBytes();
        final fileName =
            'chat_covers/${DateTime.now().millisecondsSinceEpoch}.jpg';
        await SupabaseService.client.storage
            .from('chat-media')
            .uploadBinary(fileName, bytes);
        coverUrl = SupabaseService.client.storage
            .from('chat-media')
            .getPublicUrl(fileName);
      }

      // Usar RPC create_group_chat que:
      // 1. Valida membership na comunidade
      // 2. Usa 'group' em vez de 'private' (enum válido)
      // 3. Usa host_id em vez de created_by (coluna correta)
      // 4. Não insere 'role' em chat_members (coluna não existe)
      // 5. Cria mensagem de sistema automaticamente
      final result = await SupabaseService.rpc('create_group_chat', params: {
        'p_community_id': _selectedCommunityId,
        'p_title': _nameController.text.trim(),
        'p_description': _descriptionController.text.trim().isNotEmpty
            ? _descriptionController.text.trim()
            : null,
        'p_icon_url': coverUrl,
        'p_is_public': _isPublic,
        'p_member_ids': _selectedMemberIds.toList(),
      });

      final resultMap = result is Map ? result : {};
      final success = resultMap['success'] as bool? ?? false;
      final threadId = resultMap['thread_id'] as String?;
      final error = resultMap['error'] as String?;

      if (!success || threadId == null) {
        final errorMsg = switch (error) {
          'unauthenticated' => s.needToBeLoggedIn,
          'title_required' => 'Digite um nome para o grupo.',
          'not_a_member' => s.notMemberCommunity,
          _ => s.errorCreatingGroup,
        };
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(errorMsg)),
          );
        }
        return;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(s.groupCreatedSuccessfully),
            backgroundColor: context.nexusTheme.accentPrimary,
            behavior: SnackBarBehavior.floating,
          ),
        );
        context.go('/chat/$threadId');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(s.errorCreatingGroup)),
        );
      }
    } finally {
      if (mounted) setState(() => _isCreating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
      final s = ref.watch(stringsProvider);
    final r = context.r;
    return Scaffold(
      backgroundColor: context.nexusTheme.backgroundPrimary,
      appBar: AppBar(
        backgroundColor: context.nexusTheme.backgroundPrimary,
        elevation: 0,
        title: Text(
          s.createGroup,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: context.nexusTheme.textPrimary,
            fontSize: r.fs(18),
          ),
        ),
        iconTheme: IconThemeData(color: context.nexusTheme.textPrimary),
        actions: [
          if (_currentStep == 2)
            TextButton(
              onPressed: _isCreating ? null : _createGroupChat,
              child: _isCreating
                  ? SizedBox(
                      width: r.s(16),
                      height: r.s(16),
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: context.nexusTheme.accentPrimary),
                    )
                  : Text(
                      s.create,
                      style: TextStyle(
                        color: context.nexusTheme.accentPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: r.fs(15),
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
    final s = getStrings();
    final r = context.r;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: r.s(24), vertical: r.s(16)),
      child: Row(
        children: [
          _buildStepDot(0, s.community),
          _buildStepLine(0),
          _buildStepDot(1, s.info),
          _buildStepLine(1),
          _buildStepDot(2, s.members),
        ],
      ),
    );
  }

  Widget _buildStepDot(int step, String label) {
    final r = context.r;
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
            color: isActive ? context.nexusTheme.accentPrimary : context.surfaceColor,
            border: Border.all(
              color: isActive
                  ? context.nexusTheme.accentPrimary
                  : (Colors.grey[700] ?? Colors.grey),
              width: 2,
            ),
            boxShadow: isCurrent
                ? [
                    BoxShadow(
                      color: context.nexusTheme.accentPrimary.withValues(alpha: 0.3),
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
        SizedBox(height: r.s(4)),
        Text(
          label,
          style: TextStyle(
            color: isActive ? context.nexusTheme.textPrimary : Colors.grey[600],
            fontSize: r.fs(10),
            fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ],
    );
  }

  Widget _buildStepLine(int afterStep) {
    final r = context.r;
    final isActive = _currentStep > afterStep;
    return Expanded(
      child: Container(
        height: 2,
        margin: EdgeInsets.only(bottom: r.s(16)),
        color: isActive ? context.nexusTheme.accentPrimary : Colors.grey[800],
      ),
    );
  }

  // ==========================================================================
  // STEP 0: SELECIONAR COMUNIDADE
  // ==========================================================================
  Widget _buildCommunityStep() {
    final s = getStrings();
    final r = context.r;
    if (_isLoadingCommunities) {
      return Center(
        child: CircularProgressIndicator(
            color: context.nexusTheme.accentPrimary, strokeWidth: 2),
      );
    }

    if (_communities.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.groups_rounded, size: r.s(48), color: Colors.grey[600]),
            SizedBox(height: r.s(12)),
            Text(s.noCommunitiesFound,
                style: TextStyle(color: Colors.grey[500])),
            SizedBox(height: r.s(8)),
            Text(s.joinCommunityFirst,
                style: TextStyle(color: Colors.grey[600], fontSize: r.fs(12))),
          ],
        ),
      );
    }

    return ListView(
      padding: EdgeInsets.all(r.s(16)),
      children: [
        Text(
          s.selectCommunityForGroup,
          style: TextStyle(
            color: Colors.grey[400],
            fontSize: r.fs(14),
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: r.s(16)),
        ..._communities.map((community) {
          final id = community['id'] as String?;
          final name = community['name'] as String? ?? s.community;
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
              margin: EdgeInsets.only(bottom: r.s(8)),
              padding: EdgeInsets.all(r.s(14)),
              decoration: BoxDecoration(
                color: isSelected
                    ? context.nexusTheme.accentPrimary.withValues(alpha: 0.15)
                    : context.surfaceColor,
                borderRadius: BorderRadius.circular(r.s(12)),
                border: Border.all(
                  color: isSelected
                      ? context.nexusTheme.accentPrimary
                      : Colors.white.withValues(alpha: 0.08),
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: r.s(44),
                    height: r.s(44),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(r.s(12)),
                      color: context.nexusTheme.surfacePrimary,
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: iconUrl != null
                        ? CachedNetworkImage(
                            imageUrl: iconUrl, fit: BoxFit.cover)
                        : Icon(Icons.groups_rounded,
                            color: context.nexusTheme.textHint, size: r.s(22)),
                  ),
                  SizedBox(width: r.s(14)),
                  Expanded(
                    child: Text(
                      name,
                      style: TextStyle(
                        color: context.nexusTheme.textPrimary,
                        fontWeight:
                            isSelected ? FontWeight.w700 : FontWeight.w500,
                        fontSize: r.fs(15),
                      ),
                    ),
                  ),
                  if (isSelected)
                    Icon(Icons.check_circle_rounded,
                        color: context.nexusTheme.accentPrimary, size: r.s(22)),
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
    final s = getStrings();
    final r = context.r;
    return ListView(
      padding: EdgeInsets.all(r.s(16)),
      children: [
        // Cover image
        GestureDetector(
          onTap: _pickCoverImage,
          child: Container(
            height: r.s(140),
            decoration: BoxDecoration(
              color: context.surfaceColor,
              borderRadius: BorderRadius.circular(r.s(16)),
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
                          size: r.s(36), color: Colors.grey[600]),
                      SizedBox(height: r.s(8)),
                      Text(s.addCoverOptional,
                          style: TextStyle(
                              color: Colors.grey[600], fontSize: r.fs(13))),
                    ],
                  )
                : null,
          ),
        ),
        SizedBox(height: r.s(20)),

        // Nome do grupo
        Text(s.groupName2,
            style: TextStyle(
                color: Colors.grey[400],
                fontSize: r.fs(13),
                fontWeight: FontWeight.w600)),
        SizedBox(height: r.s(8)),
        TextField(
          controller: _nameController,
          style: TextStyle(color: context.nexusTheme.textPrimary, fontSize: r.fs(16)),
          decoration: InputDecoration(
            hintText: s.exampleGroupName,
            hintStyle: TextStyle(color: Colors.grey[600]),
            filled: true,
            fillColor: context.surfaceColor,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(r.s(12)),
              borderSide: BorderSide.none,
            ),
            contentPadding:
                EdgeInsets.symmetric(horizontal: r.s(16), vertical: r.s(14)),
          ),
        ),
        SizedBox(height: r.s(20)),

        // Descricao
        Text(s.descriptionOptional,
            style: TextStyle(
                color: Colors.grey[400],
                fontSize: r.fs(13),
                fontWeight: FontWeight.w600)),
        SizedBox(height: r.s(8)),
        TextField(
          controller: _descriptionController,
          style: TextStyle(color: context.nexusTheme.textPrimary, fontSize: r.fs(14)),
          maxLines: 3,
          decoration: InputDecoration(
            hintText: s.describeGroup,
            hintStyle: TextStyle(color: Colors.grey[600]),
            filled: true,
            fillColor: context.surfaceColor,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(r.s(12)),
              borderSide: BorderSide.none,
            ),
            contentPadding:
                EdgeInsets.symmetric(horizontal: r.s(16), vertical: r.s(14)),
          ),
        ),
        SizedBox(height: r.s(20)),

        // Publico/Privado toggle
        Container(
          padding: EdgeInsets.all(r.s(16)),
          decoration: BoxDecoration(
            color: context.surfaceColor,
            borderRadius: BorderRadius.circular(r.s(12)),
          ),
          child: Row(
            children: [
              Icon(
                _isPublic ? Icons.public_rounded : Icons.lock_rounded,
                color: _isPublic ? context.nexusTheme.accentPrimary : Colors.orange,
                size: r.s(22),
              ),
              SizedBox(width: r.s(12)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _isPublic ? s.publicChat : s.privateChatLabel,
                      style: TextStyle(
                        color: context.nexusTheme.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: r.fs(14),
                      ),
                    ),
                    Text(
                      _isPublic
                          ? s.anyMemberCanJoin
                          : s.invitedMembersOnly,
                      style: TextStyle(
                          color: Colors.grey[500], fontSize: r.fs(11)),
                    ),
                  ],
                ),
              ),
              Switch(
                value: _isPublic,
                onChanged: (v) => setState(() => _isPublic = v),
                activeColor: context.nexusTheme.accentPrimary,
              ),
            ],
          ),
        ),
        SizedBox(height: r.s(24)),

        // Comunidade selecionada
        Container(
          padding: EdgeInsets.all(r.s(12)),
          decoration: BoxDecoration(
            color: context.nexusTheme.accentPrimary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(r.s(10)),
          ),
          child: Row(
            children: [
              Icon(Icons.groups_rounded,
                  color: context.nexusTheme.accentPrimary, size: r.s(18)),
              SizedBox(width: r.s(8)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.communityLabel,
                      style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: r.fs(11),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (_selectedCommunityName != null)
                      Text(
                        _selectedCommunityName!,
                        style: TextStyle(
                          color: context.nexusTheme.accentPrimary,
                          fontSize: r.fs(13),
                          fontWeight: FontWeight.w700,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () => setState(() => _currentStep = 0),
                child: Text(s.change,
                    style: TextStyle(
                        color: context.nexusTheme.accentSecondary,
                        fontSize: r.fs(12),
                        fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
        SizedBox(height: r.s(24)),

        // Botao avancar
        GestureDetector(
          onTap: () {
            if (_nameController.text.trim().isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(s.enterGroupName)),
              );
              return;
            }
            setState(() => _currentStep = 2);
            _loadMembers();
          },
          child: Container(
            padding: EdgeInsets.symmetric(vertical: r.s(14)),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [context.nexusTheme.accentPrimary, context.nexusTheme.accentSecondary],
              ),
              borderRadius: BorderRadius.circular(r.s(12)),
              boxShadow: [
                BoxShadow(
                  color: context.nexusTheme.accentPrimary.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Center(
              child: Text(
                s.selectMembers2,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: r.fs(15),
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
    final s = getStrings();
    final r = context.r;
    return Column(
      children: [
        // Search bar
        Padding(
          padding: EdgeInsets.fromLTRB(r.s(16), r.s(8), r.s(16), r.s(8)),
          child: TextField(
            controller: _searchController,
            style: TextStyle(color: context.nexusTheme.textPrimary, fontSize: r.fs(14)),
            decoration: InputDecoration(
              hintText: s.searchMembers,
              hintStyle: TextStyle(color: Colors.grey[600]),
              prefixIcon: Icon(Icons.search_rounded,
                  color: Colors.grey[600], size: r.s(20)),
              filled: true,
              fillColor: context.surfaceColor,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(r.s(12)),
                borderSide: BorderSide.none,
              ),
              contentPadding:
                  EdgeInsets.symmetric(horizontal: r.s(16), vertical: r.s(10)),
            ),
          ),
        ),

        // Selected count
        if (_selectedMemberIds.isNotEmpty)
          Padding(
            padding:
                EdgeInsets.symmetric(horizontal: r.s(16), vertical: r.s(4)),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.symmetric(
                      horizontal: r.s(10), vertical: r.s(4)),
                  decoration: BoxDecoration(
                    color: context.nexusTheme.accentPrimary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(r.s(12)),
                  ),
                  child: Text(
                    '${_selectedMemberIds.length} selecionado(s)',
                    style: TextStyle(
                      color: context.nexusTheme.accentPrimary,
                      fontSize: r.fs(12),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => setState(() => _selectedMemberIds.clear()),
                  child: Text(s.clear,
                      style: TextStyle(
                          color: Colors.grey[500],
                          fontSize: r.fs(12),
                          fontWeight: FontWeight.w500)),
                ),
              ],
            ),
          ),

        // Members list
        Expanded(
          child: _isLoadingMembers
              ? Center(
                  child: CircularProgressIndicator(
                      color: context.nexusTheme.accentPrimary, strokeWidth: 2),
                )
              : _filteredMembers.isEmpty
                  ? Center(
                      child: Text(s.noMemberFound,
                          style: TextStyle(color: Colors.grey[500])),
                    )
                  : ListView.builder(
                      padding: EdgeInsets.symmetric(horizontal: r.s(16)),
                      itemCount: _filteredMembers.length,
                      itemBuilder: (context, index) {
                        final member = _filteredMembers[index];
                        final profile =
                            member['profiles'] as Map<String, dynamic>? ?? {};
                        final userId = profile['id'] as String? ??
                            member['user_id'] as String? ??
                            '';
                        final nickname =
                            profile['nickname'] as String? ?? s.user3;
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
                            padding: EdgeInsets.symmetric(vertical: r.s(10)),
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
                                  width: r.s(22),
                                  height: r.s(22),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: isSelected
                                        ? context.nexusTheme.accentPrimary
                                        : Colors.transparent,
                                    border: Border.all(
                                      color: isSelected
                                          ? context.nexusTheme.accentPrimary
                                          : (Colors.grey[600] ?? Colors.grey),
                                      width: 2,
                                    ),
                                  ),
                                  child: isSelected
                                      ? Icon(Icons.check_rounded,
                                          color: Colors.white, size: r.s(14))
                                      : null,
                                ),
                                SizedBox(width: r.s(12)),
                                // Avatar
                                CircleAvatar(
                                  radius: 20,
                                  backgroundColor: context.nexusTheme.accentPrimary
                                      .withValues(alpha: 0.2),
                                  backgroundImage: avatarUrl != null
                                      ? CachedNetworkImageProvider(avatarUrl)
                                      : null,
                                  child: avatarUrl == null
                                      ? Text(
                                          nickname[0].toUpperCase(),
                                          style: TextStyle(
                                            color: context.nexusTheme.accentPrimary,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        )
                                      : null,
                                ),
                                SizedBox(width: r.s(12)),
                                // Info
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        nickname,
                                        style: TextStyle(
                                          color: context.nexusTheme.textPrimary,
                                          fontWeight: FontWeight.w600,
                                          fontSize: r.fs(14),
                                        ),
                                      ),
                                      if (role != 'member')
                                        Container(
                                          margin: const EdgeInsets.only(top: 2),
                                          padding: EdgeInsets.symmetric(
                                              horizontal: r.s(6), vertical: 1),
                                          decoration: BoxDecoration(
                                            color: role == 'leader'
                                                ? Colors.amber
                                                    .withValues(alpha: 0.2)
                                                : context.nexusTheme.accentPrimary
                                                    .withValues(alpha: 0.2),
                                            borderRadius:
                                                BorderRadius.circular(r.s(4)),
                                          ),
                                          child: Text(
                                            role == 'leader'
                                                ? s.leader2
                                                : role == 'curator'
                                                    ? s.curator2
                                                    : role,
                                            style: TextStyle(
                                              color: role == 'leader'
                                                  ? Colors.amber
                                                  : context.nexusTheme.accentPrimary,
                                              fontSize: r.fs(10),
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
