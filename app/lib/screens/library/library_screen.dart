import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/auth_service.dart';
import '../../services/api_service.dart';
import '../../services/request_guard.dart';
import '../../theme.dart';
import '../../widgets/gold_card.dart';
import '../../widgets/shimmer_loading.dart';
import '../../widgets/loading_button.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});
  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen>
    with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> _books = [];
  bool _loading = true;
  late AnimationController _animCtrl;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fade = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _load();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final token = context.read<AuthService>().token;
    RequestGuard.requireSessionOrReauth(context, token);
    if (token == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    try {
      final res = await ApiService.get('/books', token: token);
      final list = (res['books'] as List?) ?? (res['data'] as List?) ?? [];
      if (mounted) {
        setState(() {
          _books = List<Map<String, dynamic>>.from(list);
          _loading = false;
        });
        _animCtrl.forward(from: 0);
      }
    } on ApiException catch (e) {
      await RequestGuard.handleApiException(context, e, onRetry: _load);
      if (mounted) setState(() => _loading = false);
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _deleteBook(String id) async {
    final token = context.read<AuthService>().token;
    RequestGuard.requireSessionOrReauth(context, token);
    if (token == null) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ObrohColors.obsidian800,
        title: const Text(
          'Delete Book',
          style: TextStyle(color: ObrohColors.foreground),
        ),
        content: const Text(
          'Remove this book from your library?',
          style: TextStyle(color: ObrohColors.foreground60),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Delete',
              style: TextStyle(color: ObrohColors.error),
            ),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await ApiService.delete('/books/$id', token: token);
      await _load();
    } on ApiException catch (e) {
      await RequestGuard.handleApiException(
        context,
        e,
        onRetry: () => _deleteBook(id),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed: $e'),
            backgroundColor: ObrohColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _openForm({Map<String, dynamic>? book}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _BookFormScreen(book: book, onSaved: _load),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Library'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            tooltip: 'Add Book',
            onPressed: () => _openForm(),
          ),
        ],
      ),
      body: _loading
          ? ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: 4,
              itemBuilder: (_, _) => const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: ShimmerLoading(height: 100, borderRadius: 16),
              ),
            )
          : _books.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.menu_book_outlined,
                    color: ObrohColors.gold400.withValues(alpha: 0.3),
                    size: 56,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No books yet',
                    style: TextStyle(
                      color: ObrohColors.foreground60,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Add your literary works and publications',
                    style: TextStyle(
                      color: ObrohColors.foreground.withValues(alpha: 0.3),
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: () => _openForm(),
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('Add First Book'),
                  ),
                ],
              ),
            )
          : FadeTransition(
              opacity: _fade,
              child: RefreshIndicator(
                color: ObrohColors.gold400,
                onRefresh: _load,
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _books.length,
                  itemBuilder: (_, i) => _BookCard(
                    book: _books[i],
                    onEdit: () => _openForm(book: _books[i]),
                    onDelete: () =>
                        _deleteBook(_books[i]['id']?.toString() ?? ''),
                  ),
                ),
              ),
            ),
    );
  }
}

// ─── Book Card ────────────────────────────────────────────────────────────────

class _BookCard extends StatelessWidget {
  final Map<String, dynamic> book;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _BookCard({
    required this.book,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final title = book['title']?.toString() ?? 'Untitled';
    final synopsis = book['synopsis']?.toString();
    final coverUrl = book['coverImageUrl']?.toString();
    final pdfUrl = book['pdfUrl']?.toString();

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GoldCard(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cover
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 72,
                height: 96,
                child: coverUrl != null && coverUrl.isNotEmpty
                    ? Image.network(
                        ApiService.imageUrl(coverUrl),
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => _coverPlaceholder(title),
                      )
                    : _coverPlaceholder(title),
              ),
            ),
            const SizedBox(width: 14),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: ObrohColors.foreground,
                    ),
                  ),
                  if (synopsis != null && synopsis.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      synopsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: ObrohColors.foreground.withValues(alpha: 0.55),
                        height: 1.45,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 10),
                  // Action chips
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      if (pdfUrl != null && pdfUrl.isNotEmpty)
                        _ActionChip(
                          label: 'Read PDF',
                          icon: Icons.picture_as_pdf_rounded,
                          color: ObrohColors.error,
                          onTap: () async {
                            final url = Uri.parse(ApiService.imageUrl(pdfUrl));
                            if (await canLaunchUrl(url)) {
                              launchUrl(
                                url,
                                mode: LaunchMode.externalApplication,
                              );
                            }
                          },
                        ),
                      _ActionChip(
                        label: 'Edit',
                        icon: Icons.edit_rounded,
                        color: ObrohColors.gold400,
                        onTap: onEdit,
                      ),
                      _ActionChip(
                        label: 'Delete',
                        icon: Icons.delete_outline_rounded,
                        color: ObrohColors.error,
                        onTap: onDelete,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _coverPlaceholder(String title) {
    return Container(
      color: ObrohColors.obsidian700,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.menu_book_rounded,
              color: ObrohColors.gold400,
              size: 28,
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 8,
                  color: ObrohColors.foreground60,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _ActionChip({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    ),
  );
}

// ─── Book Form Screen ─────────────────────────────────────────────────────────

class _BookFormScreen extends StatefulWidget {
  final Map<String, dynamic>? book;
  final VoidCallback onSaved;
  const _BookFormScreen({this.book, required this.onSaved});
  @override
  State<_BookFormScreen> createState() => _BookFormScreenState();
}

class _BookFormScreenState extends State<_BookFormScreen> {
  final _titleCtrl = TextEditingController();
  final _synopsisCtrl = TextEditingController();
  final _pdfUrlCtrl = TextEditingController();
  final _coverUrlCtrl = TextEditingController();
  final _purchaseCtrl = TextEditingController();
  final _sortCtrl = TextEditingController(text: '0');
  bool _saving = false;
  bool _uploadingPdf = false;
  bool _uploadingCover = false;

  @override
  void initState() {
    super.initState();
    final b = widget.book;
    if (b != null) {
      _titleCtrl.text = b['title']?.toString() ?? '';
      _synopsisCtrl.text = b['synopsis']?.toString() ?? '';
      _pdfUrlCtrl.text = b['pdfUrl']?.toString() ?? '';
      _coverUrlCtrl.text = b['coverImageUrl']?.toString() ?? '';
      _purchaseCtrl.text = b['purchaseLinks']?.toString() ?? '';
      _sortCtrl.text = b['sortOrder']?.toString() ?? '0';
    }
  }

  @override
  void dispose() {
    for (final c in [
      _titleCtrl,
      _synopsisCtrl,
      _pdfUrlCtrl,
      _coverUrlCtrl,
      _purchaseCtrl,
      _sortCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_titleCtrl.text.trim().isEmpty) return;
    setState(() => _saving = true);
    try {
      final token = context.read<AuthService>().token;
      RequestGuard.requireSessionOrReauth(context, token);
      if (token == null) {
        if (mounted) setState(() => _saving = false);
        return;
      }
      final body = <String, dynamic>{
        'title': _titleCtrl.text.trim(),
        'synopsis': _synopsisCtrl.text.trim().isEmpty
            ? null
            : _synopsisCtrl.text.trim(),
        'purchaseLinks': _purchaseCtrl.text.trim().isEmpty
            ? null
            : _purchaseCtrl.text.trim(),
        'sortOrder': int.tryParse(_sortCtrl.text) ?? 0,
      };
      if (_pdfUrlCtrl.text.trim().isNotEmpty) {
        body['pdfUrl'] = _pdfUrlCtrl.text.trim();
      }
      if (_coverUrlCtrl.text.trim().isNotEmpty) {
        body['coverImageUrl'] = _coverUrlCtrl.text.trim();
      }

      final id = widget.book?['id']?.toString();
      if (id != null) {
        await ApiService.put('/books/$id', token: token, body: body);
      } else {
        await ApiService.post('/books', token: token, body: body);
      }
      widget.onSaved();
      if (mounted) Navigator.pop(context);
    } on ApiException catch (e) {
      await RequestGuard.handleApiException(context, e, onRetry: _save);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message),
            backgroundColor: ObrohColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to save book.'),
            backgroundColor: ObrohColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _uploadPdf() async {
    final token = context.read<AuthService>().token;
    RequestGuard.requireSessionOrReauth(context, token);
    if (token == null) return;
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
      allowMultiple: false,
    );
    if (result == null ||
        result.files.isEmpty ||
        result.files.single.path == null) {
      return;
    }

    setState(() => _uploadingPdf = true);
    try {
      final res = await ApiService.multipartPost(
        '/books/upload-pdf',
        fields: const {},
        fileField: 'file',
        filePath: result.files.single.path!,
        token: token,
      );
      final url = res['url']?.toString() ?? '';
      if (url.isNotEmpty) {
        setState(() => _pdfUrlCtrl.text = url);
      }
    } on ApiException catch (e) {
      await RequestGuard.handleApiException(context, e, onRetry: _uploadPdf);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _uploadingPdf = false);
    }
  }

  Future<void> _uploadCover() async {
    final token = context.read<AuthService>().token;
    RequestGuard.requireSessionOrReauth(context, token);
    if (token == null) return;
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
    );
    if (result == null ||
        result.files.isEmpty ||
        result.files.single.path == null) {
      return;
    }

    setState(() => _uploadingCover = true);
    try {
      final res = await ApiService.multipartPost(
        '/books/upload-cover',
        fields: const {},
        fileField: 'file',
        filePath: result.files.single.path!,
        token: token,
      );
      final url = res['url']?.toString() ?? '';
      if (url.isNotEmpty) {
        setState(() => _coverUrlCtrl.text = url);
      }
    } on ApiException catch (e) {
      await RequestGuard.handleApiException(context, e, onRetry: _uploadCover);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _uploadingCover = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.book != null ? 'Edit Book' : 'Add Book'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _field(_titleCtrl, 'Title *', Icons.title_rounded),
            const SizedBox(height: 12),
            _field(
              _synopsisCtrl,
              'Synopsis',
              Icons.description_rounded,
              maxLines: 4,
            ),
            const SizedBox(height: 12),
            _field(_pdfUrlCtrl, 'PDF URL', Icons.picture_as_pdf_rounded),
            const SizedBox(height: 8),
            _uploadBtn(
              icon: Icons.upload_file_rounded,
              label: _uploadingPdf ? 'Uploading PDF...' : 'Upload PDF',
              loading: _uploadingPdf,
              onTap: _uploadingPdf ? null : _uploadPdf,
            ),
            const SizedBox(height: 12),
            _field(_coverUrlCtrl, 'Cover Image URL', Icons.image_rounded),
            const SizedBox(height: 8),
            _uploadBtn(
              icon: Icons.image_outlined,
              label: _uploadingCover
                  ? 'Uploading Cover...'
                  : 'Upload Cover Image',
              loading: _uploadingCover,
              onTap: _uploadingCover ? null : _uploadCover,
            ),
            const SizedBox(height: 12),
            _field(
              _purchaseCtrl,
              'Purchase Links (JSON)',
              Icons.shopping_cart_outlined,
              maxLines: 3,
            ),
            const SizedBox(height: 12),
            _field(
              _sortCtrl,
              'Sort Order',
              Icons.sort_rounded,
              keyboard: TextInputType.number,
            ),
            const SizedBox(height: 24),
            LoadingButton(
              onPressed: _save,
              loading: _saving,
              label: widget.book != null ? 'Save Changes' : 'Add Book',
              icon: Icons.save_rounded,
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController ctrl,
    String label,
    IconData icon, {
    int maxLines = 1,
    TextInputType keyboard = TextInputType.text,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: ObrohColors.obsidian800.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ObrohColors.gold400.withValues(alpha: 0.1)),
      ),
      child: Row(
        crossAxisAlignment: maxLines > 1
            ? CrossAxisAlignment.start
            : CrossAxisAlignment.center,
        children: [
          Padding(
            padding: EdgeInsets.only(top: maxLines > 1 ? 14 : 0),
            child: Icon(
              icon,
              size: 16,
              color: ObrohColors.gold400.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: ctrl,
              maxLines: maxLines,
              keyboardType: keyboard,
              style: const TextStyle(
                color: ObrohColors.foreground,
                fontSize: 14,
              ),
              decoration: InputDecoration(
                labelText: label,
                labelStyle: TextStyle(
                  color: ObrohColors.foreground.withValues(alpha: 0.4),
                  fontSize: 12,
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _uploadBtn({
    required IconData icon,
    required String label,
    required bool loading,
    required VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Ink(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: ObrohColors.obsidian800.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: ObrohColors.gold400.withValues(alpha: 0.15),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (loading)
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(ObrohColors.gold400),
                ),
              )
            else
              Icon(icon, size: 16, color: ObrohColors.gold400),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: ObrohColors.foreground,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
