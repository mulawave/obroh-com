import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../services/api_service.dart';
import '../../services/request_guard.dart';
import '../../theme.dart';
import '../../widgets/gold_card.dart';
import '../../widgets/shimmer_loading.dart';

class LegalScreen extends StatefulWidget {
  const LegalScreen({super.key});

  @override
  State<LegalScreen> createState() => _LegalScreenState();
}

class _LegalScreenState extends State<LegalScreen> {
  List<Map<String, dynamic>> _declarations = [];
  bool _loading = true;
  bool _creating = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final token = context.read<AuthService>().token;
    RequestGuard.requireSessionOrReauth(context, token);
    if (token == null) return;
    try {
      final res = await ApiService.get('/legal', token: token);
      if (mounted) {
        setState(() {
          _declarations = List<Map<String, dynamic>>.from(
            res['declarations'] ?? [],
          );
          _loading = false;
        });
      }
    } on ApiException catch (e) {
      await RequestGuard.handleApiException(context, e, onRetry: _load);
      if (mounted) setState(() => _loading = false);
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  bool _isUserEditableStatus(String? status) {
    return status == 'submitted' || status == 'needs-attention';
  }

  String _statusOf(Map<String, dynamic> declaration) {
    return declaration['status']?.toString().toLowerCase() ?? 'submitted';
  }

  Future<void> _openDeclarationForm({Map<String, dynamic>? declaration}) async {
    final titleController = TextEditingController(
      text: declaration?['title']?.toString() ?? '',
    );
    final descriptionController = TextEditingController(
      text: declaration?['description']?.toString() ?? '',
    );
    String type = declaration?['type']?.toString() ?? 'other';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: ObrohColors.obsidian900,
              title: Text(
                declaration == null ? 'New Declaration' : 'Edit Declaration',
                style: const TextStyle(color: ObrohColors.foreground),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: titleController,
                      style: const TextStyle(color: ObrohColors.foreground),
                      decoration: const InputDecoration(labelText: 'Title'),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: type,
                      decoration: const InputDecoration(labelText: 'Type'),
                      dropdownColor: ObrohColors.obsidian900,
                      items: const [
                        DropdownMenuItem(
                          value: 'name-change',
                          child: Text('Name Change'),
                        ),
                        DropdownMenuItem(
                          value: 'court-affidavit',
                          child: Text('Court Affidavit'),
                        ),
                        DropdownMenuItem(
                          value: 'marital-status',
                          child: Text('Marital Status'),
                        ),
                        DropdownMenuItem(
                          value: 'custodial',
                          child: Text('Custodial'),
                        ),
                        DropdownMenuItem(value: 'other', child: Text('Other')),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        setDialogState(() => type = value);
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: descriptionController,
                      maxLines: 4,
                      style: const TextStyle(color: ObrohColors.foreground),
                      decoration: const InputDecoration(
                        labelText: 'Description',
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context, true);
                  },
                  child: Text(declaration == null ? 'Create' : 'Save'),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmed != true) return;

    final title = titleController.text.trim();
    final description = descriptionController.text.trim();
    if (title.isEmpty || description.isEmpty) {
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Title and description are required')),
      );
      return;
    }

    setState(() => _creating = true);
    try {
      final token = context.read<AuthService>().token;
      RequestGuard.requireSessionOrReauth(context, token);
      if (token == null) {
        if (mounted) setState(() => _creating = false);
        return;
      }

      if (declaration == null) {
        await ApiService.post(
          '/legal',
          token: token,
          body: {'title': title, 'type': type, 'description': description},
        );
      } else {
        await ApiService.put(
          '/legal/${declaration['id']}',
          token: token,
          body: {'title': title, 'type': type, 'description': description},
        );
      }

      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              declaration == null
                  ? 'Declaration created'
                  : 'Declaration updated and resubmitted',
            ),
          ),
        );
      }
    } on ApiException catch (e) {
      await RequestGuard.handleApiException(
        context,
        e,
        onRetry: () => _openDeclarationForm(declaration: declaration),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create declaration: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  Future<void> _cancelDeclaration(Map<String, dynamic> declaration) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ObrohColors.obsidian900,
        title: const Text(
          'Cancel Declaration',
          style: TextStyle(color: ObrohColors.foreground),
        ),
        content: const Text(
          'This will delete the declaration while it is still pending review.',
          style: TextStyle(color: ObrohColors.foreground60),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Cancel Declaration'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final token = context.read<AuthService>().token;
      RequestGuard.requireSessionOrReauth(context, token);
      if (token == null) return;

      await ApiService.delete('/legal/${declaration['id']}', token: token);
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Declaration cancelled')));
      }
    } on ApiException catch (e) {
      await RequestGuard.handleApiException(
        context,
        e,
        onRetry: () => _cancelDeclaration(declaration),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Legal Declarations')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _creating ? null : () => _openDeclarationForm(),
        backgroundColor: ObrohColors.gold400,
        foregroundColor: ObrohColors.obsidian950,
        icon: _creating
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.add_rounded),
        label: Text(_creating ? 'Creating...' : 'Add Declaration'),
      ),
      body: _loading
          ? ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: 4,
              itemBuilder: (_, _) => const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: ShimmerLoading(height: 72, borderRadius: 16),
              ),
            )
          : _declarations.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.gavel_outlined,
                    color: ObrohColors.gold400.withValues(alpha: 0.3),
                    size: 48,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No legal declarations',
                    style: TextStyle(
                      color: ObrohColors.foreground.withValues(alpha: 0.4),
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Create and manage declarations here.',
                    style: TextStyle(
                      color: ObrohColors.foreground.withValues(alpha: 0.3),
                      fontSize: 12,
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
                itemCount: _declarations.length,
                itemBuilder: (_, i) {
                  final decl = _declarations[i];
                  final status = _statusOf(decl);
                  final editable = _isUserEditableStatus(status);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: GoldCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.description_rounded,
                                color: ObrohColors.gold400,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  decl['title']?.toString() ?? 'Declaration',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: ObrohColors.foreground,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: decl['status'] == 'signed'
                                      ? ObrohColors.success.withValues(
                                          alpha: 0.15,
                                        )
                                      : ObrohColors.foreground.withValues(
                                          alpha: 0.05,
                                        ),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  decl['status']?.toString() ?? 'pending',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: decl['status'] == 'signed'
                                        ? ObrohColors.success
                                        : ObrohColors.foreground40,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (decl['description'] != null) ...[
                            const SizedBox(height: 6),
                            Text(
                              decl['description'].toString(),
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
                          if (editable) ...[
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                OutlinedButton.icon(
                                  onPressed: _creating
                                      ? null
                                      : () => _openDeclarationForm(
                                          declaration: decl,
                                        ),
                                  icon: const Icon(
                                    Icons.edit_rounded,
                                    size: 14,
                                  ),
                                  label: const Text('Edit'),
                                ),
                                OutlinedButton.icon(
                                  onPressed: _creating
                                      ? null
                                      : () => _cancelDeclaration(decl),
                                  icon: const Icon(
                                    Icons.delete_outline_rounded,
                                    size: 14,
                                  ),
                                  label: const Text('Cancel'),
                                ),
                              ],
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
}
