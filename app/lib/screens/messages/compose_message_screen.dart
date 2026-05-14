import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../services/api_service.dart';
import '../../services/request_guard.dart';
import '../../theme.dart';
import '../../widgets/loading_button.dart';

class ComposeMessageScreen extends StatefulWidget {
  const ComposeMessageScreen({super.key});

  @override
  State<ComposeMessageScreen> createState() => _ComposeMessageScreenState();
}

class _ComposeMessageScreenState extends State<ComposeMessageScreen> {
  final _subjectCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();
  final _searchCtrl = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  final List<Map<String, dynamic>> _selectedRecipients = [];
  bool _searching = false;
  bool _sending = false;
  String? _error;

  Future<void> _searchMembers(String query) async {
    if (query.trim().length < 2) {
      setState(() => _searchResults = []);
      return;
    }
    setState(() => _searching = true);
    try {
      final token = context.read<AuthService>().token;
      RequestGuard.requireSessionOrReauth(context, token);
      if (token == null) {
        if (mounted) setState(() => _searching = false);
        return;
      }
      final res = await ApiService.get(
        '/messages/search/recipients?q=${Uri.encodeComponent(query)}',
        token: token,
      );
      if (mounted) {
        final members = List<Map<String, dynamic>>.from(res['users'] ?? []);
        setState(() {
          _searchResults = members
              .where((m) => !_selectedRecipients.any((s) => s['id'] == m['id']))
              .toList();
          _searching = false;
        });
      }
    } on ApiException catch (e) {
      await RequestGuard.handleApiException(context, e);
      if (mounted) setState(() => _searching = false);
    } catch (_) {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _send() async {
    if (_selectedRecipients.isEmpty ||
        _subjectCtrl.text.trim().isEmpty ||
        _bodyCtrl.text.trim().isEmpty) {
      setState(
        () => _error =
            'Please fill in all fields and select at least one recipient.',
      );
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final token = context.read<AuthService>().token;
      RequestGuard.requireSessionOrReauth(context, token);
      if (token == null) {
        if (mounted) setState(() => _sending = false);
        return;
      }
      await ApiService.post(
        '/messages',
        token: token,
        body: {
          'recipientIds': _selectedRecipients.map((r) => r['id']).toList(),
          'subject': _subjectCtrl.text.trim(),
          'body': _bodyCtrl.text.trim(),
        },
      );
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Message sent!')));
        Navigator.pop(context, true);
      }
    } on ApiException catch (e) {
      await RequestGuard.handleApiException(context, e);
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'Failed to send message.');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  void dispose() {
    _subjectCtrl.dispose();
    _bodyCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Compose')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_error != null) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: ObrohColors.error.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: ObrohColors.error.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Text(
                          _error!,
                          style: const TextStyle(
                            color: ObrohColors.error,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],

                    // Recipient search
                    const Text(
                      'To',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: ObrohColors.foreground40,
                      ),
                    ),
                    const SizedBox(height: 6),
                    if (_selectedRecipients.isNotEmpty) ...[
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: _selectedRecipients.map((r) {
                          return Chip(
                            label: Text(
                              '${r['firstName']} ${r['lastName']}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: ObrohColors.obsidian950,
                              ),
                            ),
                            backgroundColor: ObrohColors.gold400,
                            deleteIconColor: ObrohColors.obsidian950,
                            onDeleted: () {
                              setState(
                                () => _selectedRecipients.removeWhere(
                                  (s) => s['id'] == r['id'],
                                ),
                              );
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 8),
                    ],
                    TextField(
                      controller: _searchCtrl,
                      style: const TextStyle(color: ObrohColors.foreground),
                      decoration: InputDecoration(
                        hintText: 'Search members...',
                        prefixIcon: const Icon(
                          Icons.search_rounded,
                          color: ObrohColors.foreground40,
                          size: 20,
                        ),
                        suffixIcon: _searching
                            ? const Padding(
                                padding: EdgeInsets.all(12),
                                child: SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation(
                                      ObrohColors.gold400,
                                    ),
                                  ),
                                ),
                              )
                            : null,
                      ),
                      onChanged: _searchMembers,
                    ),
                    if (_searchResults.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Container(
                        constraints: const BoxConstraints(maxHeight: 160),
                        decoration: BoxDecoration(
                          color: ObrohColors.obsidian800,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: ObrohColors.gold400.withValues(alpha: 0.1),
                          ),
                        ),
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: _searchResults.length,
                          itemBuilder: (_, i) {
                            final m = _searchResults[i];
                            return ListTile(
                              dense: true,
                              title: Text(
                                '${m['firstName']} ${m['lastName']}',
                                style: const TextStyle(
                                  color: ObrohColors.foreground,
                                  fontSize: 13,
                                ),
                              ),
                              subtitle: Text(
                                m['email']?.toString() ?? '',
                                style: TextStyle(
                                  color: ObrohColors.foreground.withValues(
                                    alpha: 0.4,
                                  ),
                                  fontSize: 11,
                                ),
                              ),
                              onTap: () {
                                setState(() {
                                  _selectedRecipients.add(m);
                                  _searchResults = [];
                                  _searchCtrl.clear();
                                });
                              },
                            );
                          },
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),

                    // Subject
                    TextField(
                      controller: _subjectCtrl,
                      style: const TextStyle(color: ObrohColors.foreground),
                      decoration: const InputDecoration(labelText: 'Subject'),
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 16),

                    // Body
                    TextField(
                      controller: _bodyCtrl,
                      style: const TextStyle(color: ObrohColors.foreground),
                      decoration: const InputDecoration(
                        labelText: 'Message',
                        alignLabelWithHint: true,
                      ),
                      maxLines: 8,
                      textInputAction: TextInputAction.newline,
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: LoadingButton(
                onPressed: _send,
                loading: _sending,
                label: 'Send Message',
                icon: Icons.send_rounded,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
