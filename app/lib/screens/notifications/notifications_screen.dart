import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../services/api_service.dart';
import '../../theme.dart';
import '../../widgets/shimmer_loading.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<Map<String, dynamic>> _notifications = [];
  bool _loading = true;
  int _unread = 0;
  bool _markingAll = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final token = context.read<AuthService>().token;
    if (token == null) return;
    try {
      final res = await ApiService.get('/notifications', token: token);
      if (mounted) {
        setState(() {
          _notifications = List<Map<String, dynamic>>.from(
            res['notifications'] ?? [],
          );
          _unread = (res['unread'] as num?)?.toInt() ?? 0;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _markAllRead() async {
    final token = context.read<AuthService>().token;
    if (token == null) return;
    setState(() => _markingAll = true);
    try {
      await ApiService.post('/notifications/read-all', token: token);
      setState(() {
        for (var n in _notifications) {
          n['isRead'] = true;
        }
        _unread = 0;
      });
    } catch (_) {}
    if (mounted) setState(() => _markingAll = false);
  }

  Future<void> _markRead(Map<String, dynamic> n) async {
    if (n['isRead'] == true) return;
    final token = context.read<AuthService>().token;
    if (token == null) return;
    try {
      await ApiService.patch('/notifications/${n['id']}/read', token: token);
      setState(() {
        n['isRead'] = true;
        _unread = (_unread - 1).clamp(0, _unread);
      });
    } catch (_) {}
  }

  IconData _typeIcon(String? type) {
    switch (type) {
      case 'message':
        return Icons.mail_rounded;
      case 'approval':
        return Icons.check_circle_rounded;
      case 'alert':
        return Icons.warning_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }

  String _formatDate(String? iso) {
    if (iso == null) return '';
    try {
      final dt = DateTime.parse(iso);
      final now = DateTime.now();
      final diff = now.difference(dt);
      if (diff.inMinutes < 1) return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      if (diff.inDays < 7) return '${diff.inDays}d ago';
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
      return '${months[dt.month - 1]} ${dt.day}';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Notifications'),
            if (_unread > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: ObrohColors.gold400,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$_unread',
                  style: const TextStyle(
                    color: ObrohColors.obsidian950,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ],
        ),
        actions: [
          if (_unread > 0)
            TextButton(
              onPressed: _markingAll ? null : _markAllRead,
              child: _markingAll
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(ObrohColors.gold400),
                      ),
                    )
                  : const Text('Read All', style: TextStyle(fontSize: 12)),
            ),
        ],
      ),
      body: _loading
          ? ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: 6,
              itemBuilder: (_, _) => const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: ShimmerLoading(height: 64, borderRadius: 12),
              ),
            )
          : _notifications.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.notifications_off_outlined,
                    color: ObrohColors.gold400.withValues(alpha: 0.3),
                    size: 48,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'All caught up!',
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
                padding: const EdgeInsets.all(12),
                itemCount: _notifications.length,
                itemBuilder: (_, i) {
                  final n = _notifications[i];
                  final isRead = n['isRead'] == true;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => _markRead(n),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: isRead
                                ? ObrohColors.obsidian800.withValues(alpha: 0.3)
                                : ObrohColors.obsidian800.withValues(
                                    alpha: 0.6,
                                  ),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isRead
                                  ? ObrohColors.gold400.withValues(alpha: 0.05)
                                  : ObrohColors.gold400.withValues(alpha: 0.15),
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                margin: const EdgeInsets.only(top: 5),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isRead
                                      ? ObrohColors.foreground.withValues(
                                          alpha: 0.1,
                                        )
                                      : ObrohColors.gold400,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Icon(
                                _typeIcon(n['type']?.toString()),
                                size: 18,
                                color: ObrohColors.gold400.withValues(
                                  alpha: isRead ? 0.3 : 0.7,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      n['title']?.toString() ?? '',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: isRead
                                            ? FontWeight.w400
                                            : FontWeight.w700,
                                        color: isRead
                                            ? ObrohColors.foreground.withValues(
                                                alpha: 0.6,
                                              )
                                            : ObrohColors.foreground,
                                      ),
                                    ),
                                    if (n['body'] != null) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        n['body'].toString(),
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: ObrohColors.foreground
                                              .withValues(alpha: 0.4),
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                    const SizedBox(height: 4),
                                    Text(
                                      _formatDate(n['createdAt']?.toString()),
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: ObrohColors.foreground
                                            .withValues(alpha: 0.25),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }
}
