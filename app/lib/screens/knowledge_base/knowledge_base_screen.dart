import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../services/api_service.dart';
import '../../theme.dart';
import '../../widgets/gold_card.dart';
import '../../widgets/shimmer_loading.dart';

class KnowledgeBaseScreen extends StatefulWidget {
  const KnowledgeBaseScreen({super.key});

  @override
  State<KnowledgeBaseScreen> createState() => _KnowledgeBaseScreenState();
}

class _KnowledgeBaseScreenState extends State<KnowledgeBaseScreen> {
  List<Map<String, dynamic>> _articles = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final token = context.read<AuthService>().token;
    if (token == null) return;
    try {
      final res = await ApiService.get('/knowledge-base', token: token);
      final items = (res['articles'] is List)
          ? res['articles'] as List
          : (res['items'] is List)
          ? res['items'] as List
          : (res['data'] is List)
          ? res['data'] as List
          : (res['list'] is List)
          ? res['list'] as List
          : <dynamic>[];

      final parsed = items.isNotEmpty
          ? List<Map<String, dynamic>>.from(items)
          : (res.isNotEmpty && res.containsKey('id'))
          ? <Map<String, dynamic>>[res]
          : <Map<String, dynamic>>[];

      if (mounted) {
        setState(() {
          _articles = parsed;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Knowledge Base')),
      body: _loading
          ? ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: 5,
              itemBuilder: (_, _) => const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: ShimmerLoading(height: 64, borderRadius: 16),
              ),
            )
          : _articles.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.menu_book_outlined,
                    color: ObrohColors.gold400.withValues(alpha: 0.3),
                    size: 48,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No articles yet',
                    style: TextStyle(
                      color: ObrohColors.foreground.withValues(alpha: 0.4),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              color: ObrohColors.gold400,
              onRefresh: _load,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _articles.length,
                itemBuilder: (_, i) {
                  final article = _articles[i];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: GoldCard(
                      onTap: () => _openArticle(article),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            article['title']?.toString() ?? 'Untitled',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: ObrohColors.foreground,
                            ),
                          ),
                          if (article['category'] != null) ...[
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: ObrohColors.gold400.withValues(
                                  alpha: 0.1,
                                ),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                article['category'].toString(),
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: ObrohColors.gold400,
                                ),
                              ),
                            ),
                          ],
                          if (article['excerpt'] != null ||
                              article['content'] != null) ...[
                            const SizedBox(height: 6),
                            Text(
                              (article['excerpt'] ?? article['content'])
                                  .toString(),
                              style: TextStyle(
                                fontSize: 12,
                                color: ObrohColors.foreground.withValues(
                                  alpha: 0.5,
                                ),
                                height: 1.4,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }

  void _openArticle(Map<String, dynamic> article) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => _ArticleDetailScreen(article: article)),
    );
  }
}

class _ArticleDetailScreen extends StatelessWidget {
  final Map<String, dynamic> article;
  const _ArticleDetailScreen({required this.article});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(article['title']?.toString() ?? 'Article')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              article['title']?.toString() ?? '',
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: ObrohColors.gold400,
              ),
            ),
            if (article['category'] != null) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: ObrohColors.gold400.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  article['category'].toString(),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: ObrohColors.gold400,
                  ),
                ),
              ),
            ],
            const Divider(height: 32),
            Text(
              article['content']?.toString() ?? 'No content.',
              style: TextStyle(
                fontSize: 14,
                color: ObrohColors.foreground.withValues(alpha: 0.8),
                height: 1.7,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
