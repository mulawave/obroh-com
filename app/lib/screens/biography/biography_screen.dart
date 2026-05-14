// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../services/api_service.dart';
import '../../theme.dart';
import '../../widgets/gold_card.dart';
import '../../widgets/loading_button.dart';
import '../../widgets/shimmer_loading.dart';

class BiographyScreen extends StatefulWidget {
  const BiographyScreen({super.key});

  @override
  State<BiographyScreen> createState() => _BiographyScreenState();
}

class _BiographyScreenState extends State<BiographyScreen> {
  Map<String, dynamic>? _biography;
  bool _loading = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final token = context.read<AuthService>().token;
    if (token == null) return;
    try {
      final res = await ApiService.get('/biography', token: token);
      if (mounted) {
        setState(() {
          _biography = (res['biography'] is Map<String, dynamic>)
              ? res['biography'] as Map<String, dynamic>
              : res;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _editSettings() async {
    final slugCtrl = TextEditingController(
      text: _biography?['slug']?.toString() ?? '',
    );
    bool isPublic = _biography?['isPublic'] == true;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: ObrohColors.obsidian900,
          title: const Text(
            'Biography Settings',
            style: TextStyle(color: ObrohColors.foreground),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: slugCtrl,
                style: const TextStyle(color: ObrohColors.foreground),
                decoration: const InputDecoration(labelText: 'Public Slug'),
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                value: isPublic,
                onChanged: (v) => setDialogState(() => isPublic = v),
                title: const Text(
                  'Public Biography',
                  style: TextStyle(color: ObrohColors.foreground),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    if (ok != true) return;

    final token = context.read<AuthService>().token;
    if (token == null) return;

    setState(() => _busy = true);
    try {
      await ApiService.put(
        '/biography',
        token: token,
        body: {
          'slug': slugCtrl.text.trim().isEmpty ? null : slugCtrl.text.trim(),
          'isPublic': isPublic,
        },
      );
      await _load();
      _snack('Biography settings updated');
    } catch (e) {
      _snack('Failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _upsertSection({Map<String, dynamic>? existing}) async {
    final titleCtrl = TextEditingController(
      text: existing?['title']?.toString() ?? '',
    );
    final contentCtrl = TextEditingController(
      text: existing?['content']?.toString() ?? '',
    );
    final imageUrlCtrl = TextEditingController(
      text: existing?['imageUrl']?.toString() ?? '',
    );

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ObrohColors.obsidian900,
        title: Text(
          existing == null ? 'Add Section' : 'Edit Section',
          style: const TextStyle(color: ObrohColors.foreground),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleCtrl,
                style: const TextStyle(color: ObrohColors.foreground),
                decoration: const InputDecoration(labelText: 'Title'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: contentCtrl,
                maxLines: 6,
                style: const TextStyle(color: ObrohColors.foreground),
                decoration: const InputDecoration(labelText: 'Content'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: imageUrlCtrl,
                style: const TextStyle(color: ObrohColors.foreground),
                decoration: const InputDecoration(
                  labelText: 'Image URL (optional)',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (ok != true ||
        titleCtrl.text.trim().isEmpty ||
        contentCtrl.text.trim().isEmpty) {
      return;
    }
    final token = context.read<AuthService>().token;
    if (token == null) return;

    final payload = {
      'title': titleCtrl.text.trim(),
      'content': contentCtrl.text.trim(),
      'imageUrl': imageUrlCtrl.text.trim().isEmpty
          ? null
          : imageUrlCtrl.text.trim(),
      'sortOrder': existing?['sortOrder'] ?? 0,
    };

    try {
      if (existing == null) {
        await ApiService.post(
          '/biography/sections',
          token: token,
          body: payload,
        );
      } else {
        await ApiService.put(
          '/biography/sections/${existing['id']}',
          token: token,
          body: payload,
        );
      }
      await _load();
    } catch (e) {
      _snack('Section save failed: $e');
    }
  }

  Future<void> _deleteSection(String id) async {
    final token = context.read<AuthService>().token;
    if (token == null) return;
    try {
      await ApiService.delete('/biography/sections/$id', token: token);
      await _load();
    } catch (e) {
      _snack('Delete failed: $e');
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final sections = ((_biography?['sections'] as List?) ?? [])
        .cast<Map<String, dynamic>>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Biography'),
        actions: [
          IconButton(
            onPressed: _busy ? null : _editSettings,
            icon: const Icon(Icons.settings_rounded),
            tooltip: 'Biography Settings',
          ),
          IconButton(
            onPressed: _busy ? null : () => _upsertSection(),
            icon: const Icon(Icons.add_rounded),
            tooltip: 'Add Section',
          ),
        ],
      ),
      body: _loading
          ? Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: const [
                  ShimmerLoading(height: 24, borderRadius: 8),
                  SizedBox(height: 12),
                  ShimmerLoading(height: 200, borderRadius: 12),
                ],
              ),
            )
          : RefreshIndicator(
              color: ObrohColors.gold400,
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  GoldCard(
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Biography Visibility',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: ObrohColors.foreground,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _biography?['isPublic'] == true
                                    ? 'Public'
                                    : 'Private',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: _biography?['isPublic'] == true
                                      ? ObrohColors.success
                                      : ObrohColors.foreground60,
                                ),
                              ),
                              if ((_biography?['slug']?.toString().isNotEmpty ??
                                  false))
                                Text(
                                  '/biography/${_biography!['slug']}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: ObrohColors.foreground.withValues(
                                      alpha: 0.35,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        LoadingButton(
                          expand: false,
                          loading: _busy,
                          onPressed: _editSettings,
                          label: 'Edit',
                          icon: Icons.edit_rounded,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (sections.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 32),
                        child: Column(
                          children: [
                            Icon(
                              Icons.auto_stories_outlined,
                              color: ObrohColors.gold400.withValues(alpha: 0.3),
                              size: 48,
                            ),
                            const SizedBox(height: 14),
                            const Text(
                              'No biography sections yet',
                              style: TextStyle(
                                color: ObrohColors.foreground60,
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 10),
                            ElevatedButton.icon(
                              onPressed: () => _upsertSection(),
                              icon: const Icon(Icons.add_rounded),
                              label: const Text('Add First Section'),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    ...sections.map(
                      (section) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: GoldCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      section['title']?.toString() ?? '',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        color: ObrohColors.foreground,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: () =>
                                        _upsertSection(existing: section),
                                    icon: const Icon(
                                      Icons.edit_rounded,
                                      size: 18,
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: () => _deleteSection(
                                      section['id'].toString(),
                                    ),
                                    icon: const Icon(
                                      Icons.delete_outline_rounded,
                                      size: 18,
                                      color: ObrohColors.error,
                                    ),
                                  ),
                                ],
                              ),
                              if ((section['imageUrl']?.toString().isNotEmpty ??
                                  false)) ...[
                                const SizedBox(height: 8),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: Image.network(
                                    ApiService.imageUrl(
                                      section['imageUrl'].toString(),
                                    ),
                                    fit: BoxFit.cover,
                                    width: double.infinity,
                                    height: 160,
                                    errorBuilder: (_, _, _) => Container(
                                      height: 90,
                                      color: ObrohColors.obsidian700,
                                      alignment: Alignment.center,
                                      child: const Text(
                                        'Image unavailable',
                                        style: TextStyle(
                                          color: ObrohColors.foreground40,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                              const SizedBox(height: 8),
                              Text(
                                section['content']?.toString() ?? '',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: ObrohColors.foreground.withValues(
                                    alpha: 0.75,
                                  ),
                                  height: 1.6,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}
