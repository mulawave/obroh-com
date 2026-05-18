import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart';
import '../theme.dart';
import 'dashboard/dashboard_screen.dart';
import 'messages/messages_screen.dart';
import 'timeline/timeline_screen.dart';
import 'profile/profile_screen.dart';
import 'more/more_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;
  int _unreadMessages = 0;
  int _unreadTimelinePosts = 0;
  Timer? _pollTimer;

  final _timelineKey = GlobalKey<State>();

  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      const DashboardScreen(),
      const MessagesScreen(),
      TimelineScreen(key: _timelineKey),
      const ProfileScreen(),
      const MoreScreen(),
    ];
    _fetchCounts();
    _pollTimer = Timer.periodic(
      const Duration(minutes: 2),
      (_) => _fetchCounts(),
    );
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchCounts() async {
    final token = context.read<AuthService>().token;
    if (token == null) return;
    try {
      final results = await Future.wait([
        ApiService.get(
          '/messages/unread-count',
          token: token,
        ).catchError((_) => {'count': 0}),
        ApiService.get(
          '/timeline/unread-count',
          token: token,
        ).catchError((_) => {'count': 0}),
      ]);
      if (mounted) {
        setState(() {
          _unreadMessages = (results[0]['count'] as num?)?.toInt() ?? 0;
          _unreadTimelinePosts = (results[1]['count'] as num?)?.toInt() ?? 0;
        });
      }
    } catch (_) {}
  }

  Future<void> _clearTimelineUnreadCount() async {
    final token = context.read<AuthService>().token;
    if (token == null) return;
    try {
      await ApiService.post(
        '/timeline/mark-all-as-read',
        token: token,
        body: {},
      );
    } catch (_) {}
    if (mounted) {
      setState(() => _unreadTimelinePosts = 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: ObrohColors.gold400.withValues(alpha: 0.1)),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (i) {
            setState(() => _currentIndex = i);
            // Refresh timeline data and clear unread count when timeline tab is tapped
            if (i == 2) {
              (_timelineKey.currentState as dynamic)?.refreshData();
              _clearTimelineUnreadCount();
            }
          },
          items: [
            const BottomNavigationBarItem(
              icon: Icon(Icons.dashboard_rounded),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: _badgeIcon(Icons.mail_rounded, _unreadMessages),
              label: 'Messages',
            ),
            BottomNavigationBarItem(
              icon: _badgeIcon(
                Icons.auto_awesome_rounded,
                _unreadTimelinePosts,
              ),
              label: 'Timeline',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.person_rounded),
              label: 'Profile',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.menu_rounded),
              label: 'More',
            ),
          ],
        ),
      ),
    );
  }

  Widget _badgeIcon(IconData icon, int count) {
    return Badge(
      isLabelVisible: count > 0,
      label: Text(
        count > 99 ? '99+' : '$count',
        style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700),
      ),
      backgroundColor: ObrohColors.gold400,
      textColor: ObrohColors.obsidian950,
      child: Icon(icon),
    );
  }
}
