import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../theme.dart';
import '../../widgets/avatar_circle.dart';
import '../../widgets/gold_card.dart';
import '../portfolio/portfolio_screen.dart';
import '../timeline/timeline_screen.dart';
import '../biography/biography_screen.dart';
import '../lineage/lineage_screen.dart';
import '../knowledge_base/knowledge_base_screen.dart';
import '../legal/legal_screen.dart';
import '../library/library_screen.dart';
import '../resume/resume_screen.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final user = auth.user;

    return Scaffold(
      appBar: AppBar(title: const Text('More')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // User card
          GoldCard(
            child: Row(
              children: [
                AvatarCircle(
                  imageUrl: user?.profileImage,
                  initials: user?.initials ?? '??',
                  size: 48,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user?.fullName ?? '',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: ObrohColors.foreground,
                        ),
                      ),
                      Text(
                        user?.email ?? '',
                        style: TextStyle(
                          fontSize: 12,
                          color: ObrohColors.foreground.withValues(alpha: 0.4),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          _sectionTitle('Member Features'),
          const SizedBox(height: 8),
          _menuItem(
            context,
            icon: Icons.work_rounded,
            label: 'Portfolio',
            color: Colors.green,
            onTap: () => _push(context, const PortfolioScreen()),
          ),
          _menuItem(
            context,
            icon: Icons.auto_stories_rounded,
            label: 'Biography',
            color: Colors.purple,
            onTap: () => _push(context, const BiographyScreen()),
          ),
          _menuItem(
            context,
            icon: Icons.timeline_rounded,
            label: 'Family Timeline',
            color: Colors.blue,
            onTap: () => _push(context, const TimelineScreen()),
          ),
          _menuItem(
            context,
            icon: Icons.account_tree_rounded,
            label: 'My Lineage',
            color: ObrohColors.gold500,
            onTap: () => _push(context, const LineageScreen()),
          ),
          _menuItem(
            context,
            icon: Icons.menu_book_rounded,
            label: 'Knowledge Base',
            color: Colors.teal,
            onTap: () => _push(context, const KnowledgeBaseScreen()),
          ),
          _menuItem(
            context,
            icon: Icons.library_books_rounded,
            label: 'Library',
            color: Colors.indigo,
            onTap: () => _push(context, const LibraryScreen()),
          ),
          _menuItem(
            context,
            icon: Icons.description_rounded,
            label: 'Resume',
            color: Colors.teal,
            onTap: () => _push(context, const ResumeScreen()),
          ),
          _menuItem(
            context,
            icon: Icons.gavel_rounded,
            label: 'Legal Declarations',
            color: Colors.red,
            onTap: () => _push(context, const LegalScreen()),
          ),

          const SizedBox(height: 24),
          _sectionTitle('Account'),
          const SizedBox(height: 8),
          _menuItem(
            context,
            icon: Icons.logout_rounded,
            label: 'Sign Out',
            color: Colors.red,
            onTap: () => _confirmLogout(context),
          ),
          const SizedBox(height: 32),
          Center(
            child: Text(
              'Obroh Chronicles v1.0.0',
              style: TextStyle(
                fontSize: 11,
                color: ObrohColors.foreground.withValues(alpha: 0.2),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: ObrohColors.foreground.withValues(alpha: 0.3),
        letterSpacing: 1,
      ),
    );
  }

  Widget _menuItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: color.withValues(alpha: 0.12),
                  ),
                  child: Icon(icon, color: color, size: 18),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: ObrohColors.foreground,
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: ObrohColors.foreground.withValues(alpha: 0.2),
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _push(BuildContext context, Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  void _confirmLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ObrohColors.obsidian800,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Sign Out',
          style: TextStyle(color: ObrohColors.foreground),
        ),
        content: Text(
          'Are you sure you want to sign out?',
          style: TextStyle(
            color: ObrohColors.foreground.withValues(alpha: 0.6),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.read<AuthService>().logout();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }
}
