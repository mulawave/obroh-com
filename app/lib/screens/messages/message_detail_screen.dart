import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../services/api_service.dart';
import '../../theme.dart';
import '../../widgets/shimmer_loading.dart';

class MessageDetailScreen extends StatefulWidget {
  final String messageId;
  final String recipientId;
  final bool isInbox;

  const MessageDetailScreen({
    super.key,
    required this.messageId,
    required this.recipientId,
    this.isInbox = true,
  });

  @override
  State<MessageDetailScreen> createState() => _MessageDetailScreenState();
}

class _MessageDetailScreenState extends State<MessageDetailScreen> {
  Map<String, dynamic>? _message;
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
      final res = await ApiService.get(
        '/messages/${widget.messageId}',
        token: token,
      );
      if (mounted) {
        setState(() {
          _message = res['message'] as Map<String, dynamic>? ?? res;
          _loading = false;
        });
      }
      // Mark as read if inbox
      if (widget.isInbox) {
        await ApiService.patch(
          '/messages/${widget.recipientId}/read',
          token: token,
        ).catchError((_) => <String, dynamic>{});
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Message')),
      body: _loading
          ? Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: const [
                  ShimmerLoading(height: 24, borderRadius: 8),
                  SizedBox(height: 12),
                  ShimmerLoading(height: 16, borderRadius: 8),
                  SizedBox(height: 24),
                  ShimmerLoading(height: 120, borderRadius: 12),
                ],
              ),
            )
          : _message == null
          ? const Center(
              child: Text(
                'Message not found',
                style: TextStyle(color: ObrohColors.foreground40),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _message!['subject']?.toString() ?? '(no subject)',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: ObrohColors.foreground,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _senderInfo(),
                  const SizedBox(height: 4),
                  if (_message!['createdAt'] != null)
                    Text(
                      _formatDate(_message!['createdAt'].toString()),
                      style: TextStyle(
                        fontSize: 12,
                        color: ObrohColors.foreground.withValues(alpha: 0.3),
                      ),
                    ),
                  const Divider(height: 32),
                  Text(
                    _message!['body']?.toString() ?? '',
                    style: TextStyle(
                      fontSize: 14,
                      color: ObrohColors.foreground.withValues(alpha: 0.8),
                      height: 1.6,
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _senderInfo() {
    final sender = _message!['sender'] as Map<String, dynamic>? ?? {};
    final isGuest = _message!['isFromGuest'] == true;
    final guestName = _message!['guestName']?.toString();
    final guestEmail = _message!['guestEmail']?.toString();

    if (isGuest && guestName != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$guestName (Guest)',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: ObrohColors.gold400,
            ),
          ),
          if (guestEmail != null)
            Text(
              guestEmail,
              style: TextStyle(
                fontSize: 12,
                color: ObrohColors.foreground.withValues(alpha: 0.4),
              ),
            ),
        ],
      );
    }

    return Text(
      '${sender['firstName'] ?? ''} ${sender['lastName'] ?? ''}'.trim(),
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: ObrohColors.gold400,
      ),
    );
  }

  String _formatDate(String iso) {
    try {
      final dt = DateTime.parse(iso);
      final months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      final h = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
      final ampm = dt.hour >= 12 ? 'PM' : 'AM';
      return '${months[dt.month - 1]} ${dt.day}, ${dt.year} at $h:${dt.minute.toString().padLeft(2, '0')} $ampm';
    } catch (_) {
      return iso;
    }
  }
}
