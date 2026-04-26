import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/l10n/locale_provider.dart';
import 'package:amino_clone/config/nexus_theme_extension.dart';

/// Resultado da seleção de moldura.
///
/// [frameUrl] é a URL da imagem do frame selecionado.
/// [purchaseId] é o ID do user_purchase (para equipar globalmente se desejado).
/// [storeItemId] é o ID do store_item.
/// [isAnimated] indica se a moldura é animada (GIF / WebP animado).
/// Se o usuário cancelou, retorna null.
class FramePickerResult {
  final String? frameUrl;
  final String? purchaseId;
  final String? storeItemId;

  /// Indica se a moldura selecionada é animada (GIF / WebP animado).
  /// Lido de [asset_config.is_animated] no banco de dados.
  final bool isAnimated;

  const FramePickerResult({
    this.frameUrl,
    this.purchaseId,
    this.storeItemId,
    this.isAnimated = false,
  });

  /// Representa "sem moldura" (remover a moldura atual).
  static const FramePickerResult none = FramePickerResult();
}

/// Exibe um painel modal de seleção de molduras de avatar.
///
/// Comportamento:
/// - Mostra todas as molduras da loja (store_items com type='avatar_frame')
/// - Molduras que o usuário possui aparecem primeiro e são selecionáveis
/// - Molduras não possuídas aparecem depois com cadeado + preço + botão de compra rápida
/// - Preview do avatar com a moldura selecionada no topo do painel (alinhado corretamente)
/// - Botão ✓ confirma a seleção (retorna [FramePickerResult])
/// - Botão ✗ cancela e retorna null
/// - A escolha NÃO é persistida aqui — só quando o usuário salvar o perfil
Future<FramePickerResult?> showFramePickerSheet(
  BuildContext context, {
  required String? currentAvatarUrl,
  required String? currentFrameUrl,
}) {
  return showModalBottomSheet<FramePickerResult>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _FramePickerSheet(
      currentAvatarUrl: currentAvatarUrl,
      currentFrameUrl: currentFrameUrl,
    ),
  );
}

class _FramePickerSheet extends StatefulWidget {
  final String? currentAvatarUrl;
  final String? currentFrameUrl;

  const _FramePickerSheet({
    required this.currentAvatarUrl,
    required this.currentFrameUrl,
  });

  @override
  State<_FramePickerSheet> createState() => _FramePickerSheetState();
}

class _FramePickerSheetState extends State<_FramePickerSheet> {
  bool _isLoading = true;

  // Molduras que o usuário possui: lista de {purchase_id, store_item_id, frame_url, name, preview_url, is_animated}
  List<Map<String, dynamic>> _ownedFrames = [];

  // Todas as molduras da loja (incluindo não possuídas)
  List<Map<String, dynamic>> _allFrames = [];

  // IDs dos store_items que o usuário possui
  Set<String> _ownedStoreItemIds = {};

  // Seleção temporária (não persistida até confirmar)
  // null = sem moldura; String = frameUrl selecionada
  String? _selectedFrameUrl;
  String? _selectedPurchaseId;
  String? _selectedStoreItemId;
  bool _selectedIsAnimated = false;

  // Se a seleção atual é "sem moldura"
  bool _selectedNone = false;

  // Controle de compra em andamento
  bool _isPurchasing = false;

  @override
  void initState() {
    super.initState();
    _selectedFrameUrl = widget.currentFrameUrl;
    _loadFrames();
  }

  Future<void> _loadFrames() async {
    try {
      final userId = SupabaseService.currentUserId;

      // Buscar todas as molduras da loja em paralelo com as compras do usuário
      final futures = await Future.wait([
        // Todas as molduras ativas na loja
        SupabaseService.table('store_items')
            .select('id, name, preview_url, asset_url, asset_config, price_coins')
            .eq('type', 'avatar_frame')
            .eq('is_active', true)
            .order('sort_order', ascending: true),

        // Compras do usuário (apenas avatar_frame)
        if (userId != null)
          SupabaseService.table('user_purchases')
              .select('id, item_id, store_items!user_purchases_item_id_fkey(id, type, name, preview_url, asset_url, asset_config)')
              .eq('user_id', userId)
              .order('purchased_at', ascending: false),
      ]);

      final allStoreItems = List<Map<String, dynamic>>.from(futures[0] as List? ?? []);
      final userPurchases = userId != null
          ? List<Map<String, dynamic>>.from(futures[1] as List? ?? [])
          : <Map<String, dynamic>>[];

      // Filtrar apenas compras de avatar_frame
      final ownedPurchases = userPurchases.where((p) {
        final si = p['store_items'] as Map<String, dynamic>?;
        return si != null && (si['type'] as String?) == 'avatar_frame';
      }).toList();

      // Mapear IDs possuídos
      final ownedIds = <String>{};
      for (final p in ownedPurchases) {
        final si = p['store_items'] as Map<String, dynamic>?;
        if (si != null) {
          final id = si['id'] as String?;
          if (id != null) ownedIds.add(id);
        }
      }

      // Construir lista de molduras possuídas com purchase_id
      final owned = <Map<String, dynamic>>[];
      for (final p in ownedPurchases) {
        final si = p['store_items'] as Map<String, dynamic>?;
        if (si == null) continue;
        final frameUrl = _extractFrameUrl(si);
        final ac = si['asset_config'];
        final isAnimated = ac is Map ? (ac['is_animated'] as bool? ?? false) : false;
        owned.add({
          'purchase_id': p['id'] as String?,
          'store_item_id': si['id'] as String?,
          'name': si['name'] as String? ?? '',
          'frame_url': frameUrl,
          'preview_url': si['preview_url'] as String?,
          'is_animated': isAnimated,
        });
      }

      if (mounted) {
        setState(() {
          _ownedFrames = owned;
          _allFrames = allStoreItems;
          _ownedStoreItemIds = ownedIds;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Extrai a URL real do frame de um store_item.
  ///
  /// Priorizamos asset_config.frame_url / image_url para mostrar somente a
  /// moldura transparente no seletor, evitando thumbs promocionais tortos.
  String? _extractFrameUrl(Map<String, dynamic> item) {
    final config = item['asset_config'];
    if (config is Map) {
      final fu = config['frame_url'] as String?;
      if (fu != null && fu.isNotEmpty) return fu;
      final iu = config['image_url'] as String?;
      if (iu != null && iu.isNotEmpty) return iu;
    }
    final assetUrl = item['asset_url'] as String?;
    if (assetUrl != null && assetUrl.isNotEmpty) return assetUrl;
    final previewUrl = item['preview_url'] as String?;
    if (previewUrl != null && previewUrl.isNotEmpty) return previewUrl;
    return null;
  }

  void _selectFrame({
    String? frameUrl,
    String? purchaseId,
    String? storeItemId,
    bool none = false,
    bool isAnimated = false,
  }) {
    setState(() {
      _selectedNone = none;
      _selectedFrameUrl = none ? null : frameUrl;
      _selectedPurchaseId = none ? null : purchaseId;
      _selectedStoreItemId = none ? null : storeItemId;
      _selectedIsAnimated = none ? false : isAnimated;
    });
  }

  void _confirm() {
    if (_selectedNone) {
      Navigator.of(context).pop(FramePickerResult.none);
    } else {
      Navigator.of(context).pop(FramePickerResult(
        frameUrl: _selectedFrameUrl,
        purchaseId: _selectedPurchaseId,
        storeItemId: _selectedStoreItemId,
        isAnimated: _selectedIsAnimated,
      ));
    }
  }

  void _cancel() => Navigator.of(context).pop(null);

  /// Exibe diálogo de confirmação de compra rápida para molduras bloqueadas.
  Future<void> _quickPurchase(_FrameGridItem item) async {
    if (_isPurchasing) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Comprar moldura'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if ((item.frameUrl ?? item.previewUrl) != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: CachedNetworkImage(
                    imageUrl: item.frameUrl ?? item.previewUrl!,
                    height: 80,
                    fit: BoxFit.contain,
                    errorWidget: (_, __, ___) => const SizedBox.shrink(),
                  ),
                ),
              ),
            Text(
              item.name,
              style: const TextStyle(fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.monetization_on_rounded,
                    color: Colors.amber[600], size: 18),
                const SizedBox(width: 4),
                Text(
                  '${item.priceCoins ?? 0} moedas',
                  style: TextStyle(
                    color: Colors.amber[700],
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Comprar'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isPurchasing = true);
    try {
      final result = await SupabaseService.rpc(
        'purchase_store_item',
        params: {'p_item_id': item.storeItemId},
      );

      if (!mounted) return;

      final resultMap = result is Map<String, dynamic>
          ? result
          : (result is Map ? Map<String, dynamic>.from(result) : <String, dynamic>{});

      final error = resultMap['error'] as String?;
      if (error != null) {
        final msg = switch (error) {
          'insufficient_coins' => 'Moedas insuficientes.',
          'already_purchased' => 'Você já possui esta moldura.',
          'sold_out' => 'Item esgotado.',
          'item_not_found' => 'Item não encontrado.',
          _ => 'Erro ao comprar: $error',
        };
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: Colors.red[700]),
        );
        return;
      }

      // Compra bem-sucedida: recarregar lista e selecionar a moldura recém-comprada
      await _loadFrames();
      if (!mounted) return;

      // Encontrar a moldura recém-comprada na lista atualizada
      final newFrame = _ownedFrames.firstWhere(
        (f) => f['store_item_id'] == item.storeItemId,
        orElse: () => <String, dynamic>{},
      );
      if (newFrame.isNotEmpty) {
        _selectFrame(
          frameUrl: newFrame['frame_url'] as String?,
          purchaseId: newFrame['purchase_id'] as String?,
          storeItemId: newFrame['store_item_id'] as String?,
          isAnimated: newFrame['is_animated'] as bool? ?? false,
        );
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${item.name} comprada com sucesso!'),
          backgroundColor: Colors.green[700],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao comprar: $e'),
          backgroundColor: Colors.red[700],
        ),
      );
    } finally {
      if (mounted) setState(() => _isPurchasing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    final s = getStrings();
    final screenHeight = MediaQuery.of(context).size.height;

    return ClipRRect(
      borderRadius: BorderRadius.vertical(top: Radius.circular(r.s(20))),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          height: screenHeight * 0.82,
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor.withValues(alpha: 0.7),
            borderRadius: BorderRadius.vertical(top: Radius.circular(r.s(20))),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.1),
              width: 0.5,
            ),
          ),
          child: Column(
        children: [
          // ── Handle bar ──
          Container(
            margin: EdgeInsets.only(top: r.s(10), bottom: r.s(4)),
            width: r.s(40),
            height: r.s(4),
            decoration: BoxDecoration(
              color: Colors.grey[400],
              borderRadius: BorderRadius.circular(r.s(2)),
            ),
          ),

          // ── Header: título + botões X e ✓ ──
          Padding(
            padding: EdgeInsets.symmetric(horizontal: r.s(16), vertical: r.s(8)),
            child: Row(
              children: [
                // Botão cancelar (X)
                GestureDetector(
                  onTap: _cancel,
                  child: Container(
                    width: r.s(36),
                    height: r.s(36),
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.close_rounded,
                        color: Colors.grey[700], size: r.s(20)),
                  ),
                ),
                Expanded(
                  child: Text(
                    s.editProfileFrames,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: r.fs(16),
                      fontWeight: FontWeight.w700,
                      color: Theme.of(context).textTheme.bodyLarge?.color,
                    ),
                  ),
                ),
                // Botão confirmar (✓)
                GestureDetector(
                  onTap: _confirm,
                  child: Container(
                    width: r.s(36),
                    height: r.s(36),
                    decoration: BoxDecoration(
                      color: context.nexusTheme.accentSecondary,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.check_rounded,
                        color: Colors.white, size: r.s(20)),
                  ),
                ),
              ],
            ),
          ),

          // ── Preview do avatar com a moldura selecionada ──
          _AvatarPreview(
            avatarUrl: widget.currentAvatarUrl,
            frameUrl: _selectedFrameUrl,
            isFrameAnimated: _selectedIsAnimated,
            size: r.s(88),
          ),
          SizedBox(height: r.s(12)),

          // ── Divisor ──
          Divider(height: 1, color: Colors.grey[300]),

          // ── Grid de molduras ──
          Expanded(
            child: _isLoading
                ? Center(
                    child: CircularProgressIndicator(
                      color: context.nexusTheme.accentSecondary,
                      strokeWidth: 2.5,
                    ),
                  )
                : _buildGrid(r, s),
          ),
          ],
          ),
        ),
      ),
    );
  }
  Widget _buildGrid(Responsive r, dynamic s) {
    // Construir lista ordenada: "sem moldura" + possuídas + não possuídas
    final items = <_FrameGridItem>[];

    // Opção "sem moldura"
    items.add(_FrameGridItem.none());

    // Molduras possuídas
    for (final f in _ownedFrames) {
      final ac = f['is_animated'];
      items.add(_FrameGridItem.owned(
        purchaseId: f['purchase_id'] as String?,
        storeItemId: f['store_item_id'] as String?,
        name: f['name'] as String? ?? '',
        frameUrl: f['frame_url'] as String?,
        previewUrl: f['preview_url'] as String?,
        isAnimated: ac as bool? ?? false,
      ));
    }

    // Molduras não possuídas (da loja) — com compra rápida
    for (final si in _allFrames) {
      final id = si['id'] as String?;
      if (id == null || _ownedStoreItemIds.contains(id)) continue;
      final frameUrl = _extractFrameUrl(si);
      final ac = si['asset_config'];
      final isAnimated = ac is Map ? (ac['is_animated'] as bool? ?? false) : false;
      items.add(_FrameGridItem.locked(
        storeItemId: id,
        name: si['name'] as String? ?? '',
        frameUrl: frameUrl,
        previewUrl: si['preview_url'] as String?,
        priceCoins: si['price_coins'] as int?,
        isAnimated: isAnimated,
      ));
    }

    return GridView.builder(
      padding: EdgeInsets.all(r.s(12)),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: r.s(8),
        mainAxisSpacing: r.s(8),
        childAspectRatio: 0.78,
      ),
      itemCount: items.length,
      itemBuilder: (ctx, i) => _buildGridCell(items[i], r),
    );
  }

  Widget _buildGridCell(_FrameGridItem item, Responsive r) {
    final isSelected = item.isNone
        ? _selectedNone
        : (_selectedFrameUrl != null &&
            _selectedFrameUrl == item.frameUrl &&
            !_selectedNone);

    return GestureDetector(
      // Molduras possuídas: selecionar. Bloqueadas: compra rápida.
      onTap: item.isLocked
          ? () => _quickPurchase(item)
          : () => _selectFrame(
                frameUrl: item.frameUrl,
                purchaseId: item.purchaseId,
                storeItemId: item.storeItemId,
                none: item.isNone,
                isAnimated: item.isAnimated,
              ),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(r.s(10)),
          border: Border.all(
            color: isSelected ? context.nexusTheme.accentSecondary : Colors.transparent,
            width: 2.5,
          ),
          color: isSelected
              ? context.nexusTheme.accentSecondary.withValues(alpha: 0.08)
              : Colors.grey[100],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Expanded(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Imagem da moldura ou ícone "sem moldura"
                  Padding(
                    padding: EdgeInsets.all(r.s(6)),
                    child: item.isNone
                        ? _buildNoneCell(r)
                        : _buildFrameImage(item, r),
                  ),

                  // Overlay de cadeado para molduras bloqueadas
                  // Toque abre compra rápida (onTap no GestureDetector pai)
                  if (item.isLocked)
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(r.s(8)),
                      ),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.shopping_cart_rounded,
                                color: Colors.white, size: r.s(18)),
                            if (item.priceCoins != null) ...[
                              SizedBox(height: r.s(2)),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.monetization_on_rounded,
                                      color: Colors.amber[300], size: r.s(10)),
                                  SizedBox(width: r.s(2)),
                                  Text(
                                    '${item.priceCoins}',
                                    style: TextStyle(
                                      color: Colors.amber[300],
                                      fontSize: r.fs(9),
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),

                  // Checkmark de selecionado
                  if (isSelected)
                    Positioned(
                      top: r.s(4),
                      right: r.s(4),
                      child: Container(
                        width: r.s(18),
                        height: r.s(18),
                        decoration: BoxDecoration(
                          color: context.nexusTheme.accentSecondary,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.check_rounded,
                            color: Colors.white, size: r.s(12)),
                      ),
                    ),
                ],
              ),
            ),

            // Nome da moldura
            Padding(
              padding: EdgeInsets.only(
                  left: r.s(4), right: r.s(4), bottom: r.s(4)),
              child: Text(
                item.isNone ? 'Nenhuma' : item.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: r.fs(9),
                  color: item.isLocked ? Colors.grey[400] : Colors.grey[700],
                  fontWeight:
                      isSelected ? FontWeight.w700 : FontWeight.w400,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoneCell(Responsive r) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.grey[400]!, width: 1.5),
        color: Colors.grey[200],
      ),
      child: Icon(Icons.block_rounded, color: Colors.grey[400], size: r.s(28)),
    );
  }

  Widget _buildFrameImage(_FrameGridItem item, Responsive r) {
    final url = item.frameUrl ?? item.previewUrl;
    final previewSize = r.s(54);

    if (url == null || url.isEmpty) {
      return Container(
        width: previewSize,
        height: previewSize,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.grey[300],
        ),
        child: Icon(Icons.photo_filter_outlined,
            color: Colors.grey[500], size: r.s(28)),
      );
    }

    Widget placeholder() => Container(
          width: previewSize,
          height: previewSize,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(r.s(14)),
            color: Colors.grey[200],
          ),
        );

    Widget fallback() => Icon(
          Icons.photo_filter_outlined,
          color: Colors.grey[400],
          size: r.s(28),
        );

    final image = item.isAnimated
        ? Image.network(
            url,
            fit: BoxFit.contain,
            gaplessPlayback: true,
            errorBuilder: (_, __, ___) => fallback(),
            loadingBuilder: (_, child, progress) {
              if (progress == null) return child;
              return placeholder();
            },
          )
        : CachedNetworkImage(
            imageUrl: url,
            fit: BoxFit.contain,
            placeholder: (_, __) => placeholder(),
            errorWidget: (_, __, ___) => fallback(),
          );

    return SizedBox(
      width: previewSize,
      height: previewSize,
      child: Center(child: image),
    );
  }
}

// ─── Preview do avatar com moldura ───────────────────────────────────────────
//
// Bug fix: o widget anterior usava Positioned com offsets negativos calculados
// manualmente (top: -(frameSize - size) / 2, left: -(frameSize - size) / 2)
// para sobrepor a moldura ao avatar. Isso causava desalinhamento porque a
// moldura saía dos limites do Stack e o clipBehavior: Clip.none não era
// suficiente para garantir o alinhamento perfeito em todos os tamanhos de tela.
//
// Solução: usar um Stack com tamanho fixo = frameSize (moldura), centralizar
// o avatar com Positioned.fill + Center, e a moldura ocupa Positioned.fill
// diretamente. Isso garante alinhamento perfeito independente do tamanho.

class _AvatarPreview extends StatelessWidget {
  final String? avatarUrl;
  final String? frameUrl;
  final bool isFrameAnimated;
  final double size;

  const _AvatarPreview({
    required this.avatarUrl,
    required this.frameUrl,
    required this.size,
    this.isFrameAnimated = false,
  });

  @override
  Widget build(BuildContext context) {
    // frameSize = tamanho total do widget (moldura + margem)
    // avatarSize = tamanho do círculo do avatar dentro da moldura
    // A moldura ocupa frameSize x frameSize; o avatar fica centralizado
    // com tamanho = size (passado pelo caller).
    final frameSize = size * 1.4;
    final hasFrame = (frameUrl ?? '').isNotEmpty;

    return SizedBox(
      width: frameSize,
      height: frameSize,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Avatar centralizado no Stack
          Positioned.fill(
            child: Center(
              child: SizedBox(
                width: size,
                height: size,
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.grey[300],
                    border: hasFrame
                        ? null
                        : Border.all(color: Colors.grey[400]!, width: 1.5),
                  ),
                  child: ClipOval(
                    child: (avatarUrl ?? '').isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: avatarUrl!,
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) =>
                                Icon(Icons.person_rounded, size: size * 0.55),
                          )
                        : Icon(Icons.person_rounded,
                            color: Colors.grey[600], size: size * 0.55),
                  ),
                ),
              ),
            ),
          ),

          // Moldura sobreposta — ocupa todo o Stack (frameSize x frameSize)
          if (hasFrame)
            Positioned.fill(
              child: isFrameAnimated
                  ? Image.network(
                      frameUrl!,
                      fit: BoxFit.contain,
                      gaplessPlayback: true,
                      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                      loadingBuilder: (_, child, progress) {
                        if (progress == null) return child;
                        return const SizedBox.shrink();
                      },
                    )
                  : CachedNetworkImage(
                      imageUrl: frameUrl!,
                      fit: BoxFit.contain,
                      errorWidget: (_, __, ___) => const SizedBox.shrink(),
                      placeholder: (_, __) => const SizedBox.shrink(),
                    ),
            ),
        ],
      ),
    );
  }
}

// ─── Modelo interno do item do grid ──────────────────────────────────────────

class _FrameGridItem {
  final bool isNone;
  final bool isLocked;
  final String? purchaseId;
  final String? storeItemId;
  final String name;
  final String? frameUrl;
  final String? previewUrl;
  final int? priceCoins;

  /// Indica se a moldura é animada (GIF / WebP animado).
  final bool isAnimated;

  const _FrameGridItem({
    required this.isNone,
    required this.isLocked,
    this.purchaseId,
    this.storeItemId,
    required this.name,
    this.frameUrl,
    this.previewUrl,
    this.priceCoins,
    this.isAnimated = false,
  });

  factory _FrameGridItem.none() => const _FrameGridItem(
        isNone: true,
        isLocked: false,
        name: 'Nenhuma',
      );

  factory _FrameGridItem.owned({
    required String? purchaseId,
    required String? storeItemId,
    required String name,
    required String? frameUrl,
    required String? previewUrl,
    bool isAnimated = false,
  }) =>
      _FrameGridItem(
        isNone: false,
        isLocked: false,
        purchaseId: purchaseId,
        storeItemId: storeItemId,
        name: name,
        frameUrl: frameUrl,
        previewUrl: previewUrl,
        isAnimated: isAnimated,
      );

  factory _FrameGridItem.locked({
    required String? storeItemId,
    required String name,
    required String? frameUrl,
    required String? previewUrl,
    required int? priceCoins,
    bool isAnimated = false,
  }) =>
      _FrameGridItem(
        isNone: false,
        isLocked: true,
        storeItemId: storeItemId,
        name: name,
        frameUrl: frameUrl,
        previewUrl: previewUrl,
        priceCoins: priceCoins,
        isAnimated: isAnimated,
      );
}
