import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../../config/app_theme.dart';

/// Giphy Picker — busca e seleciona GIFs usando a API pública do Giphy.
/// Retorna a URL do GIF selecionado via Navigator.pop().
class GiphyPicker extends StatefulWidget {
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
  State<GiphyPicker> createState() => _GiphyPickerState();
}

class _GiphyPickerState extends State<GiphyPicker> {
  @override
  Widget build(BuildContext context) {
    return const _GiphyPickerBody();
  }
}

class _GiphyPickerBody extends StatefulWidget {
  final ScrollController? scrollController;
  const _GiphyPickerBody({this.scrollController});

  @override
  State<_GiphyPickerBody> createState() => _GiphyPickerBodyState();
}

class _GiphyPickerBodyState extends State<_GiphyPickerBody> {
  final _searchController = TextEditingController();
  List<Map<String, dynamic>> _gifs = [];
  bool _isLoading = false;
  String _query = '';

  // Giphy Public Beta Key (rate limited but free for dev)
  static const _apiKey = 'SUA_GIPHY_API_KEY_AQUI';

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
        setState(() {
          _gifs = List<Map<String, dynamic>>.from(data['data'] as List);
        });
      }
    } catch (_) {}
    setState(() => _isLoading = false);
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
        setState(() {
          _gifs = List<Map<String, dynamic>>.from(data['data'] as List);
        });
      }
    } catch (_) {}
    setState(() => _isLoading = false);
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
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.scaffoldBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        children: [
          // Handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.textHint,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                const Text('GIFs',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                const Spacer(),
                // Powered by GIPHY badge
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.cardColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text('Powered by GIPHY',
                      style: TextStyle(fontSize: 10, color: AppTheme.textHint)),
                ),
              ],
            ),
          ),
          // Search
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: TextField(
              controller: _searchController,
              onSubmitted: _search,
              onChanged: (v) {
                if (v.isEmpty) _loadTrending();
              },
              decoration: InputDecoration(
                hintText: 'Buscar GIFs...',
                prefixIcon:
                    const Icon(Icons.search_rounded, color: AppTheme.textHint),
                suffixIcon: _query.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          _query = '';
                          _loadTrending();
                        },
                      )
                    : null,
                filled: true,
                fillColor: AppTheme.cardColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Grid
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _gifs.isEmpty
                    ? const Center(
                        child: Text('Nenhum GIF encontrado',
                            style: TextStyle(color: AppTheme.textSecondary)),
                      )
                    : GridView.builder(
                        controller: widget.scrollController,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
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
                              borderRadius: BorderRadius.circular(12),
                              child: Image.network(
                                previewUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  color: AppTheme.cardColor,
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
