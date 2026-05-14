import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../services/api_service.dart';
import '../../theme.dart';
import '../../widgets/avatar_circle.dart';
import '../../widgets/gold_card.dart';
import '../../widgets/shimmer_loading.dart';
import 'compose_message_screen.dart';
import 'message_detail_screen.dart';

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  List<Map<String, dynamic>> _inbox = [];
  List<Map<String, dynamic>> _sent = [];
  bool _loadingInbox = true;
  bool _loadingSent = true;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _loadInbox();
    _loadSent();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadInbox() async {
    final token = context.read<AuthService>().token;
    if (token == null) return;
    try {
      final res = await ApiService.get('/messages/inbox', token: token);
      if (mounted) {
        setState(() {
          _inbox = List<Map<String, dynamic>>.from(res['messages'] ?? []);
          _loadingInbox = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingInbox = false);
    }
  }

  Future<void> _loadSent() async {
    final token = context.read<AuthService>().token;
    if (token == null) return;
    try {
      final res = await ApiService.get('/messages/sent', token: token);
      if (mounted) {
        setState(() {
          _sent = List<Map<String, dynamic>>.from(res['messages'] ?? []);
          _loadingSent = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingSent = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Messages'),
        bottom: TabBar(
          controller: _tabCtrl,
          indicatorColor: ObrohColors.gold400,
          labelColor: ObrohColors.gold400,
          unselectedLabelColor: ObrohColors.foreground40,
          tabs: const [
            Tab(text: 'Inbox'),
            Tab(text: 'Sent'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_rounded, size: 22),
            tooltip: 'Compose',
            onPressed: () async {
              final sent = await Navigator.push<bool>(
                context,
                MaterialPageRoute(builder: (_) => const ComposeMessageScreen()),
              );
              if (sent == true) {
                _loadInbox();
                _loadSent();
              }
            },
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: [
          _buildMessageList(_inbox, _loadingInbox, isInbox: true),
          _buildMessageList(_sent, _loadingSent, isInbox: false),
        ],
      ),
    );
  }

  Widget _buildMessageList(
    List<Map<String, dynamic>> messages,
    bool loading, {
    required bool isInbox,
  }) {
    if (loading) {
      return ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: 5,
        itemBuilder: (_, _) => const Padding(
          padding: EdgeInsets.only(bottom: 8),
          child: ShimmerLoading(height: 72, borderRadius: 16),
        ),
      );
    }

    if (messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.mail_outline_rounded,
              color: ObrohColors.gold400.withValues(alpha: 0.3),
              size: 48,
            ),
            const SizedBox(height: 12),
            Text(
              isInbox ? 'No messages in your inbox' : 'No sent messages',
              style: TextStyle(
                color: ObrohColors.foreground.withValues(alpha: 0.4),
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: ObrohColors.gold400,
      onRefresh: isInbox ? _loadInbox : _loadSent,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: messages.length,
        itemBuilder: (_, i) {
          final item = messages[i];
          final msg = item['message'] as Map<String, dynamic>? ?? item;
          final sender = msg['sender'] as Map<String, dynamic>? ?? {};
          final isRead = item['isRead'] == true;
          final subject = msg['subject']?.toString() ?? '(no subject)';
          final body = msg['body']?.toString() ?? '';
          final isGuest = msg['isFromGuest'] == true;
          final guestName = msg['guestName']?.toString();

          String displayName;
          String initials;
          if (isGuest && guestName != null) {
            displayName = '$guestName (Guest)';
            initials = guestName.isNotEmpty ? guestName[0].toUpperCase() : '?';
          } else {
            displayName =
                '${sender['firstName'] ?? ''} ${sender['lastName'] ?? ''}'
                    .trim();
            initials =
                '${(sender['firstName']?.toString() ?? '?')[0]}${(sender['lastName']?.toString() ?? '?')[0]}'
                    .toUpperCase();
          }

          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: GoldCard(
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => MessageDetailScreen(
                      messageId: msg['id']?.toString() ?? '',
                      recipientId: item['id']?.toString() ?? '',
                      isInbox: isInbox,
                    ),
                  ),
                );
                if (isInbox) _loadInbox();
              },
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  AvatarCircle(
                    imageUrl: sender['profileImage']?.toString(),
                    initials: initials,
                    size: 40,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                displayName,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: isRead
                                      ? FontWeight.w500
                                      : FontWeight.w700,
                                  color: ObrohColors.foreground,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (!isRead)
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: ObrohColors.gold400,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subject,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isRead
                                ? FontWeight.w400
                                : FontWeight.w600,
                            color: ObrohColors.foreground.withValues(
                              alpha: 0.7,
                            ),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          body.length > 60
                              ? '${body.substring(0, 60)}...'
                              : body,
                          style: TextStyle(
                            fontSize: 11,
                            color: ObrohColors.foreground.withValues(
                              alpha: 0.35,
                            ),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
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
    );
  }
}
