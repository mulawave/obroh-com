import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import '../../services/auth_service.dart';
import '../../services/api_service.dart';
import '../../services/request_guard.dart';
import '../../theme.dart';
import '../../widgets/avatar_circle.dart';
import '../../widgets/gold_card.dart';
import '../../widgets/shimmer_loading.dart';

// ─── Post Categories ──────────────────────────────────────────────────────────

const _kComposerCategories = [
  _ComposerCategory(
    'general',
    'General',
    Icons.forum_outlined,
    Color(0xFF60A5FA),
  ),
  _ComposerCategory('event', 'Event', Icons.event_outlined, Color(0xFFFB7185)),
  _ComposerCategory(
    'work',
    'Work',
    Icons.work_outline_rounded,
    Color(0xFF34D399),
  ),
  _ComposerCategory(
    'biography',
    'Biography',
    Icons.auto_stories_outlined,
    Color(0xFFA78BFA),
  ),
  _ComposerCategory(
    'fun',
    'Fun',
    Icons.sentiment_very_satisfied_outlined,
    Color(0xFFF59E0B),
  ),
  _ComposerCategory(
    'community',
    'Community',
    Icons.groups_outlined,
    Color(0xFF2DD4BF),
  ),
  _ComposerCategory(
    'memory',
    'Memory',
    Icons.history_edu_outlined,
    Color(0xFF38BDF8),
  ),
  _ComposerCategory(
    'announcement',
    'Announcement',
    Icons.campaign_outlined,
    Color(0xFFF97316),
  ),
];

// ─── Screen ───────────────────────────────────────────────────────────────────

class TimelineScreen extends StatefulWidget {
  const TimelineScreen({super.key});
  @override
  State<TimelineScreen> createState() => _TimelineScreenState();
}

class _TimelineScreenState extends State<TimelineScreen>
    with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> _posts = [];
  bool _loading = true;
  bool _posting = false;
  String _category = 'general';
  final _postCtrl = TextEditingController();
  final List<XFile> _pickedMedia = [];
  final _picker = ImagePicker();
  bool _mediaRationaleShown = false;

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
    _postCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final token = context.read<AuthService>().token;
    RequestGuard.requireSessionOrReauth(context, token);
    if (token == null) return;
    try {
      final res = await ApiService.get('/timeline?limit=30', token: token);
      if (mounted) {
        setState(() {
          _posts = List<Map<String, dynamic>>.from(res['posts'] ?? []);
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

  Future<void> _pickImages() async {
    await _showMediaRationaleIfNeeded();
    final picked = await _picker.pickMultiImage(
      imageQuality: 80,
      maxWidth: 1280,
    );
    if (picked.isNotEmpty && mounted) {
      setState(() {
        _pickedMedia.addAll(picked.take(10 - _pickedMedia.length));
      });
    }
  }

  Future<void> _pickVideo() async {
    await _showMediaRationaleIfNeeded();
    final picked = await _picker.pickVideo(source: ImageSource.gallery);
    if (picked != null && mounted) {
      setState(() {
        if (_pickedMedia.length < 12) _pickedMedia.add(picked);
      });
    }
  }

  void _removeMedia(int index) => setState(() => _pickedMedia.removeAt(index));

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

  Future<void> _createPost() async {
    if ((_postCtrl.text.trim().isEmpty && _pickedMedia.isEmpty) || _posting) {
      return;
    }
    setState(() => _posting = true);
    try {
      final token = context.read<AuthService>().token;
      RequestGuard.requireSessionOrReauth(context, token);
      if (token == null) {
        if (mounted) setState(() => _posting = false);
        return;
      }
      final fields = <String, String>{};
      if (_postCtrl.text.trim().isNotEmpty) {
        fields['content'] = _postCtrl.text.trim();
      }
      fields['category'] = _category;

      if (_pickedMedia.isEmpty) {
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
          filePaths: _pickedMedia.map((f) => f.path).toList(),
          token: token,
        );
      }
      _postCtrl.clear();
      setState(() => _pickedMedia.clear());
      await _load();
    } on ApiException catch (e) {
      await RequestGuard.handleApiException(context, e);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed: $e'),
            backgroundColor: ObrohColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _posting = false);
    }
  }

  Future<void> _toggleLike(String postId) async {
    final token = context.read<AuthService>().token;
    if (token == null) return;
    try {
      await ApiService.post('/timeline/$postId/like', token: token);
      await _load();
    } catch (_) {}
  }

  Future<void> _deletePost(String postId) async {
    final token = context.read<AuthService>().token;
    RequestGuard.requireSessionOrReauth(context, token);
    if (token == null) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ObrohColors.obsidian800,
        title: const Text(
          'Delete Post',
          style: TextStyle(color: ObrohColors.foreground),
        ),
        content: const Text(
          'Remove this post from the family timeline?',
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
      await ApiService.delete('/timeline/$postId', token: token);
      await _load();
    } on ApiException catch (e) {
      await RequestGuard.handleApiException(
        context,
        e,
        onRetry: () => _deletePost(postId),
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

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthService>().user;
    return Scaffold(
      appBar: AppBar(title: const Text('Family Timeline')),
      body: Column(
        children: [
          _buildComposer(user),
          Expanded(
            child: _loading
                ? ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: 5,
                    itemBuilder: (_, _) => const Padding(
                      padding: EdgeInsets.only(bottom: 12),
                      child: ShimmerLoading(height: 120, borderRadius: 16),
                    ),
                  )
                : _posts.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.article_outlined,
                          color: ObrohColors.gold400.withValues(alpha: 0.3),
                          size: 48,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No posts yet. Be the first!',
                          style: TextStyle(
                            color: ObrohColors.foreground.withValues(
                              alpha: 0.4,
                            ),
                            fontSize: 14,
                          ),
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
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        itemCount: _posts.length,
                        itemBuilder: (_, i) => _PostCard(
                          post: _posts[i],
                          currentUserId: user?.id ?? '',
                          onLike: () =>
                              _toggleLike(_posts[i]['id']?.toString() ?? ''),
                          onDelete:
                              (user?.id ==
                                  (_posts[i]['author'] as Map?)?['id']
                                      ?.toString())
                              ? () => _deletePost(
                                  _posts[i]['id']?.toString() ?? '',
                                )
                              : null,
                          token: context.read<AuthService>().token ?? '',
                          onRefresh: _load,
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildComposer(dynamic user) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 8),
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
                  controller: _postCtrl,
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
              _iconBtn(Icons.image_rounded, _pickImages, tooltip: 'Add photos'),
              const SizedBox(width: 8),
              _iconBtn(
                Icons.videocam_rounded,
                _pickVideo,
                tooltip: 'Add video',
              ),
            ],
          ),
          if (_pickedMedia.isNotEmpty) ...[
            const SizedBox(height: 10),
            _buildMediaPreviews(),
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
          _buildCategoryComposerRow(),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton.icon(
              onPressed: _posting ? null : _createPost,
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
              icon: _posting
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
                _posting ? 'Posting...' : 'Post to Feed',
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

  Widget _iconBtn(IconData icon, VoidCallback onTap, {String? tooltip}) =>
      Tooltip(
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

  Widget _buildMediaPreviews() {
    return SizedBox(
      height: 90,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(0, 2, 0, 2),
        itemCount: _pickedMedia.length,
        itemBuilder: (_, i) {
          final f = _pickedMedia[i];
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
                      errorBuilder: (_, _, _) => Container(
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
                    onTap: () => _removeMedia(i),
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: ObrohColors.obsidian950.withValues(alpha: 0.8),
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
    );
  }

  Widget _buildCategoryComposerRow() {
    return SizedBox(
      height: 38,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.zero,
        itemCount: _kComposerCategories.length,
        itemBuilder: (_, i) {
          final cat = _kComposerCategories[i];
          final active = _category == cat.key;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () {
                if (!active) setState(() => _category = cat.key);
              },
              child: Container(
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  gradient: active ? ObrohColors.goldGradient : null,
                  color: active ? null : cat.tint.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: active
                        ? ObrohColors.gold500.withValues(alpha: 0.65)
                        : cat.tint.withValues(alpha: 0.45),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      cat.icon,
                      size: 14,
                      color: active ? ObrohColors.obsidian950 : cat.tint,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      cat.label,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: active
                            ? ObrohColors.obsidian950
                            : ObrohColors.foreground.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ComposerCategory {
  final String key;
  final String label;
  final IconData icon;
  final Color tint;

  const _ComposerCategory(this.key, this.label, this.icon, this.tint);
}

// ─── Post Card ────────────────────────────────────────────────────────────────

class _PostCard extends StatefulWidget {
  final Map<String, dynamic> post;
  final String currentUserId;
  final VoidCallback onLike;
  final VoidCallback? onDelete;
  final String token;
  final VoidCallback onRefresh;

  const _PostCard({
    required this.post,
    required this.currentUserId,
    required this.onLike,
    this.onDelete,
    required this.token,
    required this.onRefresh,
  });

  @override
  State<_PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<_PostCard> {
  bool _showComments = false;
  final _commentCtrl = TextEditingController();
  bool _postingComment = false;

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  Future<void> _addComment() async {
    if (_commentCtrl.text.trim().isEmpty || _postingComment) return;
    setState(() => _postingComment = true);
    try {
      await ApiService.post(
        '/timeline/${widget.post['id']}/comment',
        token: widget.token,
        body: {'content': _commentCtrl.text.trim()},
      );
      _commentCtrl.clear();
      widget.onRefresh();
    } catch (_) {
    } finally {
      if (mounted) setState(() => _postingComment = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final author = widget.post['author'] as Map<String, dynamic>? ?? {};
    final content = widget.post['content']?.toString() ?? '';
    final likes = widget.post['_count']?['likes'] ?? 0;
    final commentCount = widget.post['_count']?['comments'] ?? 0;
    final likedList = List<Map<String, dynamic>>.from(
      widget.post['likes'] ?? [],
    );
    final liked = likedList.any((l) => l['userId'] == widget.currentUserId);
    final media = List<Map<String, dynamic>>.from(widget.post['media'] ?? []);
    final comments = List<Map<String, dynamic>>.from(
      widget.post['comments'] ?? [],
    );
    final category = widget.post['category']?.toString() ?? '';
    final pinned = widget.post['pinned'] == true;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GoldCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Author + actions
            Row(
              children: [
                AvatarCircle(
                  imageUrl: author['profileImage']?.toString(),
                  initials:
                      '${(author['firstName']?.toString() ?? '?')[0]}${(author['lastName']?.toString() ?? '?')[0]}',
                  size: 36,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              '${author['firstName'] ?? ''} ${author['lastName'] ?? ''}',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: ObrohColors.foreground,
                              ),
                            ),
                          ),
                          if (author['badges'] != null &&
                              (author['badges'] as List).isNotEmpty) ...[
                            const SizedBox(width: 6),
                            ...(author['badges'] as List)
                                .take(2)
                                .map(
                                  (b) => Container(
                                    margin: const EdgeInsets.only(right: 4),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: ObrohColors.gold400.withValues(
                                        alpha: 0.1,
                                      ),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      b['label']?.toString() ?? '',
                                      style: const TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w600,
                                        color: ObrohColors.gold400,
                                      ),
                                    ),
                                  ),
                                ),
                          ],
                        ],
                      ),
                      Row(
                        children: [
                          Text(
                            _formatDate(widget.post['createdAt']?.toString()),
                            style: TextStyle(
                              fontSize: 11,
                              color: ObrohColors.foreground.withValues(
                                alpha: 0.35,
                              ),
                            ),
                          ),
                          if (category.isNotEmpty && category != 'general') ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: ObrohColors.gold400.withValues(
                                  alpha: 0.08,
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                category,
                                style: const TextStyle(
                                  fontSize: 9,
                                  color: ObrohColors.gold400,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                          if (pinned) ...[
                            const SizedBox(width: 6),
                            Icon(
                              Icons.push_pin_rounded,
                              size: 12,
                              color: ObrohColors.gold400.withValues(alpha: 0.6),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                if (widget.onDelete != null)
                  PopupMenuButton<String>(
                    tooltip: 'Post actions',
                    color: ObrohColors.obsidian800,
                    surfaceTintColor: Colors.transparent,
                    icon: Icon(
                      Icons.more_horiz_rounded,
                      size: 20,
                      color: ObrohColors.foreground.withValues(alpha: 0.6),
                    ),
                    onSelected: (value) {
                      if (value == 'delete') {
                        widget.onDelete?.call();
                      }
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem<String>(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(
                              Icons.delete_outline_rounded,
                              color: ObrohColors.error,
                              size: 18,
                            ),
                            SizedBox(width: 8),
                            Text('Delete post'),
                          ],
                        ),
                      ),
                    ],
                  ),
              ],
            ),

            // Content
            if (content.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                content,
                style: TextStyle(
                  fontSize: 13,
                  color: ObrohColors.foreground.withValues(alpha: 0.85),
                  height: 1.5,
                ),
              ),
            ],

            // Media grid
            if (media.isNotEmpty) ...[
              const SizedBox(height: 10),
              _MediaGrid(media: media),
            ],

            // Like + comment bar
            const SizedBox(height: 10),
            Row(
              children: [
                _actionBtn(
                  Icons.favorite_rounded,
                  '$likes',
                  liked
                      ? ObrohColors.error
                      : ObrohColors.foreground.withValues(alpha: 0.4),
                  onTap: widget.onLike,
                ),
                const SizedBox(width: 16),
                _actionBtn(
                  Icons.comment_rounded,
                  '$commentCount',
                  ObrohColors.foreground.withValues(alpha: 0.4),
                  onTap: () => setState(() => _showComments = !_showComments),
                ),
              ],
            ),

            // Comments section
            if (_showComments) ...[
              const Divider(height: 16, thickness: 1),
              ...comments.map((c) => _CommentTile(comment: c)),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _commentCtrl,
                      style: const TextStyle(
                        color: ObrohColors.foreground,
                        fontSize: 12,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Add a comment...',
                        hintStyle: TextStyle(
                          color: ObrohColors.foreground.withValues(alpha: 0.3),
                          fontSize: 12,
                        ),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide(
                            color: ObrohColors.gold400.withValues(alpha: 0.12),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide(
                            color: ObrohColors.gold400.withValues(alpha: 0.12),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _postingComment
                      ? const SizedBox(
                          width: 28,
                          height: 28,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation(
                              ObrohColors.gold400,
                            ),
                          ),
                        )
                      : GestureDetector(
                          onTap: _addComment,
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: ObrohColors.gold400,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.send_rounded,
                              size: 14,
                              color: ObrohColors.obsidian950,
                            ),
                          ),
                        ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _actionBtn(
    IconData icon,
    String label,
    Color color, {
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: ObrohColors.foreground.withValues(alpha: 0.5),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(String? iso) {
    if (iso == null) return '';
    try {
      final dt = DateTime.parse(iso).toLocal();
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 1) return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      if (diff.inDays < 7) return '${diff.inDays}d ago';
      const months = [
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
}

// ─── Comment Tile ─────────────────────────────────────────────────────────────

class _CommentTile extends StatelessWidget {
  final Map<String, dynamic> comment;
  const _CommentTile({required this.comment});

  @override
  Widget build(BuildContext context) {
    final author = comment['author'] as Map<String, dynamic>? ?? {};
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AvatarCircle(
            imageUrl: author['profileImage']?.toString(),
            initials:
                '${(author['firstName']?.toString() ?? '?')[0]}${(author['lastName']?.toString() ?? '?')[0]}',
            size: 28,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: ObrohColors.obsidian700.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${author['firstName'] ?? ''} ${author['lastName'] ?? ''}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: ObrohColors.gold400,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    comment['content']?.toString() ?? '',
                    style: TextStyle(
                      fontSize: 12,
                      color: ObrohColors.foreground.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Media Grid ───────────────────────────────────────────────────────────────

class _MediaGrid extends StatefulWidget {
  final List<Map<String, dynamic>> media;
  const _MediaGrid({required this.media});
  @override
  State<_MediaGrid> createState() => _MediaGridState();
}

class _MediaGridState extends State<_MediaGrid> {
  int? _lightboxIndex;

  void _openLightbox(int i) => setState(() => _lightboxIndex = i);
  void _closeLightbox() => setState(() => _lightboxIndex = null);

  @override
  Widget build(BuildContext context) {
    final images = widget.media.where((m) => m['type'] == 'image').toList();
    final videos = widget.media.where((m) => m['type'] == 'video').toList();
    final n = images.length;

    return Stack(
      children: [
        Column(
          children: [
            if (videos.isNotEmpty) _VideoRow(videos: videos),
            if (images.isNotEmpty) _buildImageGrid(images, n),
          ],
        ),
        if (_lightboxIndex != null)
          _Lightbox(
            images: images,
            startIndex: _lightboxIndex!,
            onClose: _closeLightbox,
          ),
      ],
    );
  }

  Widget _buildImageGrid(List<Map<String, dynamic>> images, int n) {
    final h = BorderRadius.circular(12);
    if (n == 1) {
      return ClipRRect(
        borderRadius: h,
        child: _NetImg(
          images[0],
          maxHeight: 320,
          onTap: () => _openLightbox(0),
        ),
      );
    }
    if (n == 2) {
      return ClipRRect(
        borderRadius: h,
        child: Row(
          children: [
            Expanded(
              child: _NetImg(
                images[0],
                aspectRatio: 4 / 3,
                onTap: () => _openLightbox(0),
              ),
            ),
            const SizedBox(width: 2),
            Expanded(
              child: _NetImg(
                images[1],
                aspectRatio: 4 / 3,
                onTap: () => _openLightbox(1),
              ),
            ),
          ],
        ),
      );
    }
    if (n == 3) {
      return ClipRRect(
        borderRadius: h,
        child: Row(
          children: [
            Expanded(
              flex: 2,
              child: _NetImg(images[0], onTap: () => _openLightbox(0)),
            ),
            const SizedBox(width: 2),
            Expanded(
              child: Column(
                children: [
                  _NetImg(
                    images[1],
                    aspectRatio: 1,
                    onTap: () => _openLightbox(1),
                  ),
                  const SizedBox(height: 2),
                  _NetImg(
                    images[2],
                    aspectRatio: 1,
                    onTap: () => _openLightbox(2),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }
    return ClipRRect(
      borderRadius: h,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _NetImg(
                  images[0],
                  aspectRatio: 4 / 3,
                  onTap: () => _openLightbox(0),
                ),
              ),
              const SizedBox(width: 2),
              Expanded(
                child: _NetImg(
                  images[1],
                  aspectRatio: 4 / 3,
                  onTap: () => _openLightbox(1),
                ),
              ),
            ],
          ),
          if (n > 2) ...[
            const SizedBox(height: 2),
            Row(
              children: [
                Expanded(
                  child: _NetImg(
                    images[2],
                    aspectRatio: 4 / 3,
                    onTap: () => _openLightbox(2),
                  ),
                ),
                const SizedBox(width: 2),
                Expanded(
                  child: Stack(
                    children: [
                      _NetImg(
                        n > 3 ? images[3] : images[2],
                        aspectRatio: 4 / 3,
                        onTap: () => _openLightbox(3),
                      ),
                      if (n > 4)
                        Positioned.fill(
                          child: GestureDetector(
                            onTap: () => _openLightbox(3),
                            child: Container(
                              decoration: BoxDecoration(
                                color: ObrohColors.obsidian950.withValues(
                                  alpha: 0.6,
                                ),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Center(
                                child: Text(
                                  '+${n - 4}',
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _NetImg extends StatelessWidget {
  final Map<String, dynamic> media;
  final double? aspectRatio;
  final double? maxHeight;
  final VoidCallback? onTap;
  const _NetImg(this.media, {this.aspectRatio, this.maxHeight, this.onTap});

  @override
  Widget build(BuildContext context) {
    final url = ApiService.imageUrl(media['url']?.toString());
    Widget img = Image.network(
      url,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => Container(
        color: ObrohColors.obsidian800,
        child: const Icon(
          Icons.image_not_supported_outlined,
          color: ObrohColors.foreground20,
        ),
      ),
    );
    if (aspectRatio != null) {
      img = AspectRatio(aspectRatio: aspectRatio!, child: img);
    }
    if (maxHeight != null) {
      img = ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight!),
        child: img,
      );
    }
    return GestureDetector(onTap: onTap, child: img);
  }
}

class _VideoRow extends StatelessWidget {
  final List<Map<String, dynamic>> videos;
  const _VideoRow({required this.videos});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Column(
        children: videos.map((v) {
          return _VideoPlayer(video: v);
        }).toList(),
      ),
    );
  }
}

class _VideoPlayer extends StatefulWidget {
  final Map<String, dynamic> video;
  const _VideoPlayer({required this.video});
  @override
  State<_VideoPlayer> createState() => _VideoPlayerState();
}

class _VideoPlayerState extends State<_VideoPlayer> {
  late VideoPlayerController _controller;
  late Future<void> _initializeVideoPlayerFuture;
  bool _showPlayButton = true;

  @override
  void initState() {
    super.initState();
    final url = ApiService.imageUrl(widget.video['url']?.toString());
    _controller = VideoPlayerController.networkUrl(
      Uri.parse(url),
      httpHeaders: {},
    );

    _initializeVideoPlayerFuture = _controller.initialize().catchError((error) {
      print("Video initialization error: $error");
      return null;
    });

    _controller.addListener(_videoListener);
  }

  void _videoListener() {
    if (!mounted) return;
    if (_controller.value.isPlaying && _showPlayButton) {
      setState(() => _showPlayButton = false);
    } else if (!_controller.value.isPlaying && !_showPlayButton && _controller.value.position != Duration.zero) {
      // Only hide play button if video is not at the start
      if (_controller.value.position != Duration.zero) {
        return;
      }
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_videoListener);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final thumbnailUrl = widget.video['thumbnailUrl']?.toString();
    
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: ObrohColors.obsidian800,
        borderRadius: BorderRadius.circular(12),
      ),
      child: FutureBuilder<void>(
        future: _initializeVideoPlayerFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            return GestureDetector(
              onTap: () => setState(() {
                if (_controller.value.isPlaying) {
                  _controller.pause();
                  setState(() => _showPlayButton = true);
                } else {
                  _controller.play();
                  setState(() => _showPlayButton = false);
                }
              }),
              child: AspectRatio(
                aspectRatio: _controller.value.aspectRatio,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    VideoPlayer(_controller),
                    if (_showPlayButton)
                      Container(
                        decoration: BoxDecoration(
                          color: ObrohColors.obsidian950.withValues(alpha: 0.3),
                          shape: BoxShape.circle,
                        ),
                        padding: const EdgeInsets.all(16),
                        child: Icon(
                          Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: 48,
                        ),
                      ),
                  ],
                ),
              ),
            );
          } else if (snapshot.hasError) {
            return AspectRatio(
              aspectRatio: 16 / 9,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  color: ObrohColors.obsidian900,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.videocam_off_rounded,
                        color: ObrohColors.error,
                        size: 48,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Video unavailable',
                        style: TextStyle(
                          color: ObrohColors.foreground.withValues(alpha: 0.6),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          } else {
            // Loading state - show thumbnail if available
            return AspectRatio(
              aspectRatio: 16 / 9,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    if (thumbnailUrl != null)
                      Image.network(
                        ApiService.imageUrl(thumbnailUrl),
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: ObrohColors.obsidian900,
                        ),
                      )
                    else
                      Container(color: ObrohColors.obsidian900),
                    const SizedBox(
                      width: 40,
                      height: 40,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }
        },
      ),
    );
  }

class _Lightbox extends StatefulWidget {
  final List<Map<String, dynamic>> images;
  final int startIndex;
  final VoidCallback onClose;
  const _Lightbox({
    required this.images,
    required this.startIndex,
    required this.onClose,
  });
  @override
  State<_Lightbox> createState() => _LightboxState();
}

class _LightboxState extends State<_Lightbox> {
  late int _idx;
  @override
  void initState() {
    super.initState();
    _idx = widget.startIndex;
  }

  @override
  Widget build(BuildContext context) {
    final img = widget.images[_idx];
    final url = ApiService.imageUrl(img['url']?.toString() ?? '');
    return GestureDetector(
      onTap: widget.onClose,
      child: Container(
        color: ObrohColors.obsidian950.withValues(alpha: 0.95),
        child: Stack(
          children: [
            Center(
              child: Image.network(
                url,
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => const Icon(
                  Icons.broken_image_outlined,
                  color: ObrohColors.foreground40,
                  size: 48,
                ),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: GestureDetector(
                onTap: widget.onClose,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: ObrohColors.obsidian800,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.close,
                    color: ObrohColors.foreground,
                    size: 18,
                  ),
                ),
              ),
            ),
            if (_idx > 0)
              Positioned(
                left: 8,
                top: 0,
                bottom: 0,
                child: Center(
                  child: GestureDetector(
                    onTap: () {
                      setState(() => _idx--);
                    },
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: ObrohColors.obsidian800.withValues(alpha: 0.8),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.chevron_left,
                        color: ObrohColors.foreground,
                      ),
                    ),
                  ),
                ),
              ),
            if (_idx < widget.images.length - 1)
              Positioned(
                right: 8,
                top: 0,
                bottom: 0,
                child: Center(
                  child: GestureDetector(
                    onTap: () {
                      setState(() => _idx++);
                    },
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: ObrohColors.obsidian800.withValues(alpha: 0.8),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.chevron_right,
                        color: ObrohColors.foreground,
                      ),
                    ),
                  ),
                ),
              ),
            Positioned(
              bottom: 12,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: widget.images
                    .asMap()
                    .entries
                    .map(
                      (e) => GestureDetector(
                        onTap: () => setState(() => _idx = e.key),
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: e.key == _idx
                                ? ObrohColors.gold400
                                : ObrohColors.foreground.withValues(alpha: 0.3),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
