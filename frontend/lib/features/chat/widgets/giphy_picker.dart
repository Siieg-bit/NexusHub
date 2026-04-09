import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../../config/app_theme.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/l10n/locale_provider.dart';

/// Giphy Picker — busca e seleciona GIFs usando a API pública do Giphy.
/// Retorna a URL do GIF selecionado via Navigator.pop().
class GiphyPicker extends ConsumerStatefulWidget {
  const GiphyPicker({super.key});

  /// Abre o picker como bottom sheet e retorna a URL do GIF selecionado.
  static Future<String?> show(BuildContext context) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (ctx, scrollController) =>
            _GiphyPickerBody(scrollController: scrollController),
      ),
    );
  }

  @override
  ConsumerState<GiphyPicker> createState() => _GiphyPickerState();
}

class _GiphyPickerState extends ConsumerState<GiphyPicker> {
  @override
  Widget build(BuildContext context) {
      final s = ref.watch(stringsProvider);
    return const _GiphyPickerBody();
  }
}

class _GiphyPickerBody extends ConsumerStatefulWidget {
  final ScrollController? scrollController;
  const _GiphyPickerBody({this.scrollController});

  @override
  ConsumerState<_GiphyPickerBody> createState() => _GiphyPickerBodyState();
}

class _GiphyPickerBodyState extends ConsumerState<_GiphyPickerBody> {
  final _searchController = TextEditingController();
  List<Map<String, dynamic>> _gifs = [];
  bool _isLoading = false;
  String _query = '';

  // Giphy Public Beta Key (rate limited but free for dev)
  static const _apiKey = 'XaT2twgclfFioBckgzQFjs9IxRAPodOc';

  @override
  void initState() {
    super.initState();
    _loadTrending();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadTrending() async {
    setState(() => _isLoading = true);
    try {
      final url = Uri.parse(
          'https://api.giphy.com/v1/gifs/trending?api_key=$_apiKey&limit=30&rating=pg-13');
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (!mounted) return;
        setState(() {
          _gifs = List<Map<String, dynamic>>.from(data['data'] as List? ?? []);
        });
      }
    } catch (e) {
      debugPrint('[giphy_picker] Erro: $e');
    }
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _search(String query) async {
    if (query.trim().isEmpty) {
      _loadTrending();
      return;
    }
    setState(() {
      _isLoading = true;
      _query = query;
    });
    try {
      final url = Uri.parse(
          'https://api.giphy.com/v1/gifs/search?api_key=$_apiKey&q=${Uri.encodeComponent(query)}&limit=30&rating=pg-13');
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (!mounted) return;
        setState(() {
          _gifs = List<Map<String, dynamic>>.from(data['data'] as List? ?? []);
        });
      }
    } catch (e) {
      debugPrint('[giphy_picker] Erro: $e');
    }
    if (mounted) setState(() => _isLoading = false);
  }

  String _getGifUrl(Map<String, dynamic> gif) {
    try {
      return gif['images']['fixed_height']['url'] as String? ?? '';
    } catch (_) {
      return '';
    }
  }

  String _getPreviewUrl(Map<String, dynamic> gif) {
    try {
      return gif['images']['fixed_height_small']['url'] as String? ??
          _getGifUrl(gif);
    } catch (_) {
      return _getGifUrl(gif);
    }
  }

  @override
  Widget build(BuildContext context) {
      final s = ref.watch(stringsProvider);
    final r = context.r;
    return Container(
      decoration: BoxDecoration(
        color: context.scaffoldBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        children: [
          // Handle
          Center(
            child: Container(
              margin: EdgeInsets.only(top: r.s(8)),
              width: r.s(40),
              height: r.s(4),
              decoration: BoxDecoration(
                color: context.textHint,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Header
          Padding(
            padding: EdgeInsets.all(r.s(12)),
            child: Row(
              children: [
                Text(s.gifs,
                    style: TextStyle(
                        fontWeight: FontWeight.bold, fontSize: r.fs(18))),
                const Spacer(),
                // Powered by GIPHY badge
                Container(
                  padding: EdgeInsets.symmetric(
                      horizontal: r.s(8), vertical: r.s(4)),
                  decoration: BoxDecoration(
                    color: context.cardBg,
                    borderRadius: BorderRadius.circular(r.s(8)),
                  ),
                  child: Text('Powered by GIPHY',
                      style: TextStyle(
                          fontSize: r.fs(10), color: context.textHint)),
                ),
              ],
            ),
          ),
          // Search
          Padding(
            padding: EdgeInsets.symmetric(horizontal: r.s(12)),
            child: TextField(
              controller: _searchController,
              onSubmitted: _search,
              onChanged: (v) {
                if (v.isEmpty) _loadTrending();
              },
              decoration: InputDecoration(
                hintText: 'Buscar GIFs...',
                prefixIcon: Icon(Icons.search_rounded, color: context.textHint),
                suffixIcon: _query.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear_rounded, size: r.s(18)),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _query = '');
                          _loadTrending();
                        },
                      )
                    : null,
                filled: true,
                fillColor: context.cardBg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(r.s(12)),
                  borderSide: BorderSide.none,
                ),
                contentPadding: EdgeInsets.symmetric(
                    horizontal: r.s(16), vertical: r.s(10)),
              ),
            ),
          ),
          SizedBox(height: r.s(12)),
          // Grid
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _gifs.isEmpty
                    ? Center(
                        child: Text(s.noGifFound,
                            style: TextStyle(color: context.textSecondary)),
                      )
                    : GridView.builder(
                        controller: widget.scrollController,
                        padding: EdgeInsets.symmetric(horizontal: r.s(12)),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                          childAspectRatio: 1.2,
                        ),
                        itemCount: _gifs.length,
                        itemBuilder: (context, index) {
                          final gif = _gifs[index];
                          final previewUrl = _getPreviewUrl(gif);
                          final fullUrl = _getGifUrl(gif);
                          if (previewUrl.isEmpty) {
                            return const SizedBox.shrink();
                          }
                          return GestureDetector(
                            onTap: () => Navigator.pop(context, fullUrl),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(r.s(12)),
                              child: Image.network(
                                previewUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  color: context.cardBg,
                                  child: const Center(
                                      child: Icon(Icons.broken_image_rounded)),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
