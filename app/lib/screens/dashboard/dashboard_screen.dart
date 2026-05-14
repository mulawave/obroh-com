import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../services/request_guard.dart';
import '../../theme.dart';
import '../../widgets/avatar_circle.dart';
import '../../widgets/gold_card.dart';
import '../../widgets/shimmer_loading.dart';
import '../biography/biography_screen.dart';
import '../knowledge_base/knowledge_base_screen.dart';
import '../legal/legal_screen.dart';
import '../library/library_screen.dart';
import '../lineage/lineage_screen.dart';
import '../portfolio/portfolio_screen.dart';
import '../profile/profile_screen.dart';
import '../resume/resume_screen.dart';
import '../timeline/timeline_screen.dart';

const _kHomeComposerCategories = [
  _HomeComposerCategory(
    'general',
    'General',
    Icons.forum_outlined,
    Color(0xFF60A5FA),
  ),
  _HomeComposerCategory(
    'event',
    'Event',
    Icons.event_outlined,
    Color(0xFFFB7185),
  ),
  _HomeComposerCategory(
    'work',
    'Work',
    Icons.work_outline_rounded,
    Color(0xFF34D399),
  ),
  _HomeComposerCategory(
    'biography',
    'Biography',
    Icons.auto_stories_outlined,
    Color(0xFFA78BFA),
  ),
  _HomeComposerCategory(
    'fun',
    'Fun',
    Icons.sentiment_very_satisfied_outlined,
    Color(0xFFF59E0B),
  ),
  _HomeComposerCategory(
    'community',
    'Community',
    Icons.groups_outlined,
    Color(0xFF2DD4BF),
  ),
  _HomeComposerCategory(
    'memory',
    'Memory',
    Icons.history_edu_outlined,
    Color(0xFF38BDF8),
  ),
  _HomeComposerCategory(
    'announcement',
    'Announcement',
    Icons.campaign_outlined,
    Color(0xFFF97316),
  ),
];

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _unreadMessages = 0;
  int _unreadNotifications = 0;
  bool _loading = true;
  List<Map<String, dynamic>> _recentPosts = [];

  final _homePostCtrl = TextEditingController();
  final List<XFile> _homePickedMedia = [];
  final _picker = ImagePicker();
  bool _homePosting = false;
  String _homeCategory = 'general';
  bool _mediaRationaleShown = false;

  late final ScrollController _quickScrollController;
  Timer? _quickAutoSlideTimer;

  @override
  void initState() {
    super.initState();
    _quickScrollController = ScrollController();
    _startQuickAutoSlide();
    _loadData();
  }

  @override
  void dispose() {
    _quickAutoSlideTimer?.cancel();
    _quickScrollController.dispose();
    _homePostCtrl.dispose();
    super.dispose();
  }

  void _startQuickAutoSlide() {
    _quickAutoSlideTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!_quickScrollController.hasClients) return;

      final max = _quickScrollController.position.maxScrollExtent;
      if (max <= 0) return;

      final current = _quickScrollController.offset;
      final next = current + 112;
      if (next >= max) {
        _quickScrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 550),
          curve: Curves.easeInOut,
        );
      } else {
        _quickScrollController.animateTo(
          next,
          duration: const Duration(milliseconds: 550),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  Future<void> _loadData() async {
    final token = context.read<AuthService>().token;
    RequestGuard.requireSessionOrReauth(context, token);
    if (token == null) return;
    try {
      final results = await Future.wait([
        ApiService.get(
          '/messages/unread-count',
          token: token,
        ).catchError((_) => {'count': 0}),
        ApiService.get(
          '/notifications/unread-count',
          token: token,
        ).catchError((_) => {'count': 0}),
        ApiService.get(
          '/timeline?limit=5',
          token: token,
        ).catchError((_) => {'posts': []}),
      ]);
      if (mounted) {
        setState(() {
          _unreadMessages = (results[0]['count'] as num?)?.toInt() ?? 0;
          _unreadNotifications = (results[1]['count'] as num?)?.toInt() ?? 0;
          _recentPosts = List<Map<String, dynamic>>.from(
            results[2]['posts'] ?? [],
          );
          _loading = false;
        });
      }
    } on ApiException catch (e) {
      await RequestGuard.handleApiException(context, e, onRetry: _loadData);
      if (mounted) setState(() => _loading = false);
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good Morning';
    if (h < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  Future<void> _showMediaRationaleIfNeeded() async {
    if (_mediaRationaleShown || !mounted) return;
    _mediaRationaleShown = true;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ObrohColors.obsidian900,
        title: const Text(
          'Media Access Permission',
          style: TextStyle(color: ObrohColors.foreground),
        ),
        content: const Text(
          'Obroh needs access to your photos and videos so you can attach media to timeline posts. We only upload files you explicitly choose.',
          style: TextStyle(color: ObrohColors.foreground60, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }

  Future<void> _pickHomeImages() async {
    await _showMediaRationaleIfNeeded();
    final picked = await _picker.pickMultiImage(
      imageQuality: 80,
      maxWidth: 1280,
    );
    if (picked.isNotEmpty && mounted) {
      setState(() {
        _homePickedMedia.addAll(picked.take(10 - _homePickedMedia.length));
      });
    }
  }

  Future<void> _pickHomeVideo() async {
    await _showMediaRationaleIfNeeded();
    final picked = await _picker.pickVideo(source: ImageSource.gallery);
    if (picked != null && mounted) {
      setState(() {
        if (_homePickedMedia.length < 12) _homePickedMedia.add(picked);
      });
    }
  }

  void _removeHomeMedia(int index) {
    setState(() => _homePickedMedia.removeAt(index));
  }

  Future<void> _createHomePost() async {
    if ((_homePostCtrl.text.trim().isEmpty && _homePickedMedia.isEmpty) ||
        _homePosting) {
      return;
    }

    setState(() => _homePosting = true);
    final token = context.read<AuthService>().token;
    RequestGuard.requireSessionOrReauth(context, token);
    if (token == null) {
      if (mounted) setState(() => _homePosting = false);
      return;
    }
    try {
      final fields = <String, String>{'category': _homeCategory};
      if (_homePostCtrl.text.trim().isNotEmpty) {
        fields['content'] = _homePostCtrl.text.trim();
      }

      if (_homePickedMedia.isEmpty) {
        await ApiService.post(
          '/timeline',
          token: token,
          body: Map<String, dynamic>.from(fields),
        );
      } else {
        await ApiService.multipartPostFiles(
          '/timeline',
          fields: fields,
          fileField: 'media',
          filePaths: _homePickedMedia.map((f) => f.path).toList(),
          token: token,
        );
      }

      _homePostCtrl.clear();
      setState(() => _homePickedMedia.clear());
      await _loadData();
    } on ApiException catch (e) {
      await RequestGuard.handleApiException(
        context,
        e,
        onRetry: _createHomePost,
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
    } finally {
      if (mounted) setState(() => _homePosting = false);
    }
  }

  List<_HomeQuickLinkData> _quickLinks(BuildContext context) => [
    _HomeQuickLinkData(
      icon: Icons.work_rounded,
      label: 'Portfolio',
      iconColor: const Color(0xFF34D399),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const PortfolioScreen()),
      ),
    ),
    _HomeQuickLinkData(
      icon: Icons.auto_stories_rounded,
      label: 'Biography',
      iconColor: const Color(0xFFA78BFA),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const BiographyScreen()),
      ),
    ),
    _HomeQuickLinkData(
      icon: Icons.account_tree_rounded,
      label: 'My Lineage',
      iconColor: const Color(0xFFF59E0B),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const LineageScreen()),
      ),
    ),
    _HomeQuickLinkData(
      icon: Icons.library_books_rounded,
      label: 'Library',
      iconColor: const Color(0xFF818CF8),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const LibraryScreen()),
      ),
    ),
    _HomeQuickLinkData(
      icon: Icons.description_rounded,
      label: 'Resume',
      iconColor: const Color(0xFF2DD4BF),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ResumeScreen()),
      ),
    ),
    _HomeQuickLinkData(
      icon: Icons.gavel_rounded,
      label: 'Legal',
      iconColor: const Color(0xFFFB7185),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const LegalScreen()),
      ),
    ),
    _HomeQuickLinkData(
      icon: Icons.menu_book_rounded,
      label: 'Knowledge',
      iconColor: const Color(0xFF38BDF8),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const KnowledgeBaseScreen()),
      ),
    ),
    _HomeQuickLinkData(
      icon: Icons.person_rounded,
      label: 'Profile',
      iconColor: const Color(0xFF60A5FA),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ProfileScreen()),
      ),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthService>().user;
    final quickLinks = _quickLinks(context);

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          color: ObrohColors.gold400,
          onRefresh: _loadData,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${_greeting()},',
                          style: TextStyle(
                            fontSize: 14,
                            color: ObrohColors.foreground.withValues(
                              alpha: 0.5,
                            ),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          user?.firstName ?? '',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: ObrohColors.gold400,
                          ),
                        ),
                      ],
                    ),
                  ),
                  AvatarCircle(
                    imageUrl: user?.profileImage,
                    initials: user?.initials ?? '??',
                    size: 48,
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  _StatCard(
                    icon: Icons.mail_rounded,
                    label: 'Messages',
                    count: _unreadMessages,
                    color: Colors.cyan,
                    loading: _loading,
                  ),
                  const SizedBox(width: 12),
                  _StatCard(
                    icon: Icons.notifications_rounded,
                    label: 'Notifications',
                    count: _unreadNotifications,
                    color: ObrohColors.gold400,
                    loading: _loading,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const _GoldSectionDivider(),
              const SizedBox(height: 12),

              const Text(
                'Quick Access',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: ObrohColors.foreground,
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 96,
                child: ListView.separated(
                  controller: _quickScrollController,
                  scrollDirection: Axis.horizontal,
                  itemCount: quickLinks.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(width: 10),
                  itemBuilder: (_, i) => _QuickAccessCard(data: quickLinks[i]),
                ),
              ),
              const SizedBox(height: 12),
              const _GoldSectionDivider(),
              const SizedBox(height: 12),

              _buildHomeComposer(user),
              const SizedBox(height: 12),
              const _GoldSectionDivider(),
              const SizedBox(height: 12),

              Row(
                children: [
                  const Icon(
                    Icons.auto_awesome_rounded,
                    color: ObrohColors.gold400,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Family Timeline',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: ObrohColors.foreground,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const TimelineScreen()),
                    ),
                    child: const Text('See All'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (_loading)
                ...List.generate(
                  5,
                  (_) => const Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: ShimmerLoading(height: 84, borderRadius: 16),
                  ),
                )
              else if (_recentPosts.isEmpty)
                GoldCard(
                  child: Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.article_outlined,
                          color: ObrohColors.gold400.withValues(alpha: 0.4),
                          size: 32,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'No posts yet',
                          style: TextStyle(
                            color: ObrohColors.foreground.withValues(
                              alpha: 0.4,
                            ),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                ..._recentPosts
                    .take(5)
                    .map((post) => _PostPreviewCard(post: post)),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.center,
                child: InkWell(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const TimelineScreen()),
                  ),
                  borderRadius: BorderRadius.circular(10),
                  child: Ink(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: ObrohColors.obsidian800,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: ObrohColors.gold400.withValues(alpha: 0.28),
                      ),
                    ),
                    child: const Text(
                      'See More',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: ObrohColors.gold400,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHomeComposer(dynamic user) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: ObrohColors.obsidian900,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ObrohColors.gold400.withValues(alpha: 0.16)),
        boxShadow: [
          BoxShadow(
            color: ObrohColors.obsidian950.withValues(alpha: 0.55),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AvatarCircle(
                imageUrl: user?.profileImage,
                initials: user?.initials ?? '??',
                size: 38,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _homePostCtrl,
                  maxLines: 4,
                  minLines: 2,
                  style: const TextStyle(
                    color: ObrohColors.foreground,
                    fontSize: 13,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Share something with the family...',
                    hintStyle: TextStyle(
                      color: ObrohColors.foreground.withValues(alpha: 0.32),
                      fontSize: 13,
                    ),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                        color: ObrohColors.gold400.withValues(alpha: 0.15),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                        color: ObrohColors.gold400.withValues(alpha: 0.15),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _composerIconBtn(
                Icons.image_rounded,
                _pickHomeImages,
                tooltip: 'Add photos',
              ),
              const SizedBox(width: 8),
              _composerIconBtn(
                Icons.videocam_rounded,
                _pickHomeVideo,
                tooltip: 'Add video',
              ),
            ],
          ),
          if (_homePickedMedia.isNotEmpty) ...[
            const SizedBox(height: 10),
            SizedBox(
              height: 90,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(0, 2, 0, 2),
                itemCount: _homePickedMedia.length,
                itemBuilder: (_, i) {
                  final f = _homePickedMedia[i];
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: SizedBox(
                            width: 74,
                            height: 74,
                            child: Image.file(
                              File(f.path),
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  Container(
                                    color: ObrohColors.obsidian800,
                                    child: const Icon(
                                      Icons.videocam_rounded,
                                      color: ObrohColors.gold400,
                                    ),
                                  ),
                            ),
                          ),
                        ),
                        Positioned(
                          top: 2,
                          right: 2,
                          child: GestureDetector(
                            onTap: () => _removeHomeMedia(i),
                            child: Container(
                              width: 20,
                              height: 20,
                              decoration: BoxDecoration(
                                color: ObrohColors.obsidian950.withValues(
                                  alpha: 0.8,
                                ),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.close,
                                size: 12,
                                color: ObrohColors.foreground,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
          const SizedBox(height: 10),
          Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  ObrohColors.gold200.withValues(alpha: 0.05),
                  ObrohColors.gold400.withValues(alpha: 0.6),
                  ObrohColors.gold200.withValues(alpha: 0.05),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 38,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.zero,
              itemCount: _kHomeComposerCategories.length,
              itemBuilder: (_, i) {
                final cat = _kHomeComposerCategories[i];
                final active = _homeCategory == cat.key;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () {
                      if (!active) setState(() => _homeCategory = cat.key);
                    },
                    child: Container(
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        gradient: active ? ObrohColors.goldGradient : null,
                        color: active ? null : ObrohColors.obsidian800,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: active
                              ? ObrohColors.gold500.withValues(alpha: 0.65)
                              : ObrohColors.gold400.withValues(alpha: 0.24),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            cat.icon,
                            size: 14,
                            color: active
                                ? ObrohColors.obsidian950
                                : ObrohColors.gold400,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            cat.label,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: active
                                  ? ObrohColors.obsidian950
                                  : ObrohColors.foreground.withValues(
                                      alpha: 0.7,
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton.icon(
              onPressed: _homePosting ? null : _createHomePost,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF14532D),
                disabledBackgroundColor: const Color(
                  0xFF14532D,
                ).withValues(alpha: 0.75),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: const BorderSide(color: Color(0xFF166534)),
                ),
                elevation: 0,
              ),
              icon: _homePosting
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(Colors.white),
                      ),
                    )
                  : const Icon(Icons.send_rounded, size: 16),
              label: Text(
                _homePosting ? 'Posting...' : 'Post to Feed',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _composerIconBtn(
    IconData icon,
    VoidCallback onTap, {
    String? tooltip,
  }) {
    return Tooltip(
      message: tooltip ?? '',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: ObrohColors.obsidian800,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: ObrohColors.gold400.withValues(alpha: 0.18),
            ),
          ),
          child: Icon(icon, color: ObrohColors.gold400, size: 18),
        ),
      ),
    );
  }
}

class _HomeComposerCategory {
  final String key;
  final String label;
  final IconData icon;
  final Color tint;

  const _HomeComposerCategory(this.key, this.label, this.icon, this.tint);
}

class _HomeQuickLinkData {
  final IconData icon;
  final String label;
  final Color iconColor;
  final VoidCallback onTap;

  const _HomeQuickLinkData({
    required this.icon,
    required this.label,
    required this.iconColor,
    required this.onTap,
  });
}

class _GoldSectionDivider extends StatelessWidget {
  const _GoldSectionDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            ObrohColors.gold200.withValues(alpha: 0.02),
            ObrohColors.gold400.withValues(alpha: 0.72),
            ObrohColors.gold200.withValues(alpha: 0.02),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final int count;
  final Color color;
  final bool loading;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.count,
    required this.color,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GoldCard(
        padding: const EdgeInsets.all(16),
        child: loading
            ? const ShimmerLoading(height: 40)
            : Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      color: color.withValues(alpha: 0.15),
                    ),
                    child: Icon(icon, color: color, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$count unread',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: ObrohColors.foreground,
                        ),
                      ),
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 11,
                          color: ObrohColors.foreground.withValues(alpha: 0.4),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
      ),
    );
  }
}

class _QuickAccessCard extends StatelessWidget {
  final _HomeQuickLinkData data;

  const _QuickAccessCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: data.onTap,
      child: Container(
        width: 92,
        padding: const EdgeInsets.all(1),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: LinearGradient(
            colors: [
              ObrohColors.gold200.withValues(alpha: 0.45),
              ObrohColors.gold400.withValues(alpha: 0.55),
              ObrohColors.gold600.withValues(alpha: 0.45),
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: ObrohColors.gold400.withValues(alpha: 0.16),
              blurRadius: 7,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(13),
            color: ObrohColors.obsidian900,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: data.iconColor.withValues(alpha: 0.16),
                ),
                child: Icon(data.icon, color: data.iconColor, size: 16),
              ),
              const SizedBox(height: 7),
              Text(
                data.label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: ObrohColors.foreground.withValues(alpha: 0.85),
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PostPreviewCard extends StatelessWidget {
  final Map<String, dynamic> post;

  const _PostPreviewCard({required this.post});

  @override
  Widget build(BuildContext context) {
    final author = post['author'] as Map<String, dynamic>? ?? {};
    final content = post['content']?.toString() ?? '';
    final postId = post['id']?.toString() ?? '';
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GestureDetector(
        onTap: postId.isNotEmpty
            ? () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => TimelineScreen(initialPostId: postId),
              ),
            )
            : null,
        child: GoldCard(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AvatarCircle(
                imageUrl: author['profileImage']?.toString(),
                initials:
                    '${(author['firstName']?.toString() ?? '?')[0]}${(author['lastName']?.toString() ?? '?')[0]}',
                size: 36,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${author['firstName'] ?? ''} ${author['lastName'] ?? ''}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: ObrohColors.foreground,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      content.length > 140
                          ? '${content.substring(0, 140)}...'
                          : content,
                      style: TextStyle(
                        fontSize: 12,
                        color: ObrohColors.foreground.withValues(alpha: 0.6),
                        height: 1.4,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
